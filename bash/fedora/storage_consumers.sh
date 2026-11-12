#!/bin/bash
# Managed by PDS storage maintenance.

_pds_consumer_warn() {
    printf 'WARN %s\n' "$*"
    if (( consumer_status == 0 )); then consumer_status=1; fi
}

_pds_consumer_error() {
    printf 'ERROR %s\n' "$*" >&2
    consumer_status=2
}

_pds_consumer_docker() {
    env -u DOCKER_CONTEXT -u DOCKER_HOST -u BUILDX_BUILDER \
        docker --host unix:///var/run/docker.sock "$@"
}

_pds_consumer_podman() {
    env -u CONTAINER_HOST -u CONTAINER_CONNECTION \
        podman --remote=false "$@"
}

_pds_consumer_docker_audit() {
    local records rows type count bytes size reclaimable volumes
    if ! command -v docker >/dev/null; then
        printf 'SKIP Docker: not installed\n'
        return 0
    fi
    command -v jq >/dev/null || { _pds_consumer_error 'Docker audit needs jq.'; return 2; }
    if ! records=$(_pds_consumer_docker system df --format '{{json .}}'); then
        _pds_consumer_error 'Installed Docker is inaccessible; accounting is unknown.'
        return 2
    fi
    rows=$(printf '%s\n' "$records" | jq -ser '
        def bytes:
            capture("^(?<n>[0-9]+(?:\\.[0-9]+)?)(?<u>B|kB|KB|MB|GB|TB)$") |
            (.n|tonumber) * ({B:1,kB:1000,KB:1000,MB:1000000,GB:1000000000,TB:1000000000000}[.u]);
        if length != 4 or
           ([.[].Type]|sort) != (["Images","Containers","Local Volumes","Build Cache"]|sort)
        then error("incomplete Docker accounting") else . end |
        .[] | [.Type, (.TotalCount|tonumber), (.Size|bytes), .Size, .Reclaimable] | @tsv
    ') || {
        _pds_consumer_error 'Malformed or incomplete Docker accounting; refuse retention.'
        return 2
    }
    while IFS=$'\t' read -r type count bytes size reclaimable; do
        printf 'INFO Docker %s: total=%s size=%s reclaimable=%s\n' "$type" "$count" "$size" "$reclaimable"
        case "$type" in
            'Build Cache') (( bytes <= 30000000000 )) || _pds_consumer_warn 'Docker Build Cache exceeds 30 GB' ;;
            Images) (( bytes <= 40000000000 )) || _pds_consumer_warn 'Docker Images exceed 40 GB' ;;
            'Local Volumes') (( bytes <= 30000000000 )) || _pds_consumer_warn 'Docker Local Volumes exceed 30 GB; no volume deletion' ;;
        esac
    done <<<"$rows"
    if ! volumes=$(_pds_consumer_docker volume ls --quiet --filter dangling=true); then
        _pds_consumer_error 'Cannot count unattached Docker volumes.'
        return 2
    fi
    if [[ -z "$volumes" ]]; then count=0; else count=$(printf '%s\n' "$volumes" | wc -l); fi
    printf 'INFO Docker unattached_volumes=%s; unattached does not mean disposable\n' "$count"
    (( count <= 50 )) || _pds_consumer_warn 'More than 50 unattached Docker volumes; inspect data ownership'
}

_pds_consumer_podman_audit() {
    local records rows type bytes reclaimable
    if ! command -v podman >/dev/null; then
        printf 'SKIP rootless Podman: not installed\n'
        return 0
    fi
    if ! records=$(_pds_consumer_podman system df --format json); then
        _pds_consumer_error 'Installed rootless Podman is inaccessible.'
        return 2
    fi
    rows=$(printf '%s\n' "$records" | jq -er '
        if type != "array" or length == 0 then error("missing Podman rows") else . end |
        if ([.[].Type]|index("Images")) == null or
           ([.[].Type]|index("Local Volumes")) == null
        then error("incomplete Podman categories") else . end |
        .[] | if (.Type|type) != "string" or (.RawSize|type) != "number" or
                   (.RawReclaimable|type) != "number" or .RawSize<0 or .RawReclaimable<0
              then error("invalid Podman accounting")
              else [.Type,.RawSize,.RawReclaimable]|@tsv end
    ') || { _pds_consumer_error 'Malformed Podman accounting.'; return 2; }
    while IFS=$'\t' read -r type bytes reclaimable; do
        printf 'INFO Podman %s: bytes=%s reclaimable_bytes=%s\n' "$type" "$bytes" "$reclaimable"
        case "$type" in
            Images) (( bytes <= 40000000000 )) || _pds_consumer_warn 'Podman images exceed 40 GB' ;;
            'Local Volumes') (( bytes <= 30000000000 )) || _pds_consumer_warn 'Podman volumes exceed 30 GB; report only' ;;
        esac
    done <<<"$rows"
}

_pds_consumer_measure() {
    local label="$1" path="$2" budget="$3" output bytes _rest result
    if [[ ! -e "$path" && ! -L "$path" ]]; then
        printf 'SKIP %s: absent path=%s\n' "$label" "$path"
        return 0
    fi
    if [[ ! -d "$path" || -L "$path" ]] || [[ "$(realpath -e -- "$path")" != "$path" ]]; then
        _pds_consumer_error "Unsafe or unknown $label directory; report only: $path"
        return 2
    fi
    if output=$(timeout --kill-after=3s 30s du -sbx -- "$path"); then
        read -r bytes _rest <<<"$output"
        _pds_storage_number "$bytes" || { consumer_status=2; return 2; }
        printf 'INFO %s: bytes=%s path=%s (read-only; overlapping totals are not additive)\n' "$label" "$bytes" "$path"
        (( bytes <= budget )) || _pds_consumer_warn "$label exceeds warning budget=$budget path=$path"
    else
        result=$?
        _pds_consumer_error "Incomplete $label scan: exit=$result path=$path"
        return 2
    fi
}

_pds_consumer_user_audit() (
    local listing path code="$storage_home/code" result=0
    _pds_consumer_podman_audit || consumer_status=2
    _pds_consumer_measure 'Go modules' "$storage_home/go/pkg/mod" 21474836480 || consumer_status=2
    _pds_consumer_measure 'npm' "$storage_home/.npm" 5368709120 || consumer_status=2
    _pds_consumer_measure 'uv' "$storage_home/.cache/uv" 5368709120 || consumer_status=2
    _pds_consumer_measure 'Zed cache' "$storage_home/.cache/zed" 5368709120 || consumer_status=2
    _pds_consumer_measure 'Zed data (not disposable)' "$storage_home/.local/share/zed" 5368709120 || consumer_status=2
    _pds_consumer_measure 'all user caches' "$storage_home/.cache" 53687091200 || consumer_status=2
    if [[ -d "$code" && ! -L "$code" && "$(realpath -e -- "$code")" == "$code" ]]; then
        _pds_consumer_measure 'builders and other code caches' "$code/.cache" 21474836480 || consumer_status=2
        _pds_consumer_measure 'review archive' "$code/.triage-review-archive" 10737418240 || consumer_status=2
        listing=$(mktemp) || exit 2
        trap 'rm -f -- "$listing"' EXIT
        if ! find "$code" -mindepth 1 -maxdepth 1 -type d \
            \( -name 'stackweaver-maintenance-*' -o -name 'stackweaver-security-full-cycle.*' \) \
            -print0 >"$listing"; then
            _pds_consumer_error 'Cannot inventory review/maintenance directories.'
        else
            while IFS= read -r -d '' path; do
                _pds_consumer_measure 'review/maintenance data' "$path" 10737418240 || consumer_status=2
            done <"$listing"
        fi
        if [[ -d "$code/.cache" && ! -L "$code/.cache" ]]; then
            if find "$code/.cache" -mindepth 1 -maxdepth 1 -type d -name 'builders-*' -print0 >"$listing"; then
                while IFS= read -r -d '' path; do
                    _pds_consumer_measure 'builders directory' "$path" 21474836480 || consumer_status=2
                done <"$listing"
            else
                _pds_consumer_error 'Cannot inventory builders directories.'
            fi
        fi
        _pds_consumer_measure 'Claude worktrees' "$code/stackweaver/.claude/worktrees" 10737418240 || consumer_status=2
        if [[ -d "$code/stackweaver" ]]; then
            if command -v git >/dev/null; then
                printf 'INFO registered worktrees and locks (no deletion)\n'
                timeout --kill-after=3s 30s git -C "$code/stackweaver" worktree list --porcelain ||
                    _pds_consumer_error 'Worktree inventory incomplete.'
            else
                _pds_consumer_error 'Cannot inventory existing worktrees: git is missing.'
            fi
        fi
    elif [[ -e "$code" || -L "$code" ]]; then
        _pds_consumer_error "Cannot safely audit aliased/invalid code root: $code"
    else
        printf 'SKIP builders/review/worktrees: canonical code root absent: %s\n' "$code"
    fi
    result="$consumer_status"
    exit "$result"
)

_pds_consumer_uv() (
    local cache="$storage_home/.cache/uv" version listing path name
    if ! command -v uv >/dev/null; then printf 'SKIP uv: not installed\n'; return 0; fi
    version=$(uv --version) || { _pds_storage_error 'Cannot verify uv version.'; return 2; }
    if [[ "$version" != 'uv 0.10.9' ]]; then
        printf 'SKIP uv prune: unverified version=%s\n' "$version"
        return 0
    fi
    if [[ ! -d "$cache" || -L "$cache" || -L "$storage_home/.cache" ||
          "$(realpath -e -- "$cache")" != "$cache" || ! -f "$cache/CACHEDIR.TAG" ]]; then
        printf 'SKIP uv prune: unverified cache path/layout\n'
        return 0
    fi
    if pgrep -u "$storage_uid" -x uv; then
        printf 'SKIP uv prune: active uv process\n'; return 0
    else
        [[ $? == 1 ]] || { _pds_storage_error 'Cannot check active uv processes.'; return 2; }
    fi
    listing=$(mktemp) || return 2
    trap 'rm -f -- "$listing"' EXIT
    find "$cache" -mindepth 1 -maxdepth 1 -print0 >"$listing" || return 2
    while IFS= read -r -d '' path; do
        name="${path##*/}"
        if [[ -L "$path" ]]; then printf 'SKIP uv prune: aliased bucket=%s\n' "$name"; return 0; fi
        case "$name" in
            environments-*) printf 'SKIP uv prune: protected environment bucket=%s\n' "$name"; return 0 ;;
            CACHEDIR.TAG|.gitignore|.lock)
                [[ -f "$path" ]] || { printf 'SKIP uv prune: unexpected metadata type\n'; return 0; } ;;
            archive-v0|builds-v0|interpreter-v4|sdists-v9|sdists-v10|simple-v20|simple-v26|wheels-v6|wheels-v7)
                [[ -d "$path" ]] || { printf 'SKIP uv prune: unexpected bucket type\n'; return 0; } ;;
            *) printf 'SKIP uv prune: unknown bucket=%s\n' "$name"; return 0 ;;
        esac
    done <"$listing"
    env -u UV_CACHE_DIR -u UV_PROJECT_ENVIRONMENT -u UV_CONFIG_FILE \
        uv --no-config --offline --cache-dir "$cache" cache prune
)

_pds_consumer_cleanup_user() {
    local path
    if command -v podman >/dev/null; then
        _pds_consumer_podman image prune --all --filter until=168h --force ||
            _pds_consumer_error 'Local Podman image retention failed.'
    else
        printf 'SKIP Podman image retention: not installed\n'
    fi
    path="$storage_home/.npm"
    if command -v npm >/dev/null; then
        if [[ -d "$path" && ! -L "$path" && "$(realpath -e -- "$path")" == "$path" ]]; then
            env NPM_CONFIG_USERCONFIG=/dev/null NPM_CONFIG_GLOBALCONFIG=/etc/npmrc \
                npm cache verify --cache "$path" || _pds_consumer_error 'Native npm verification failed.'
        else
            printf 'SKIP npm verification: cache absent or unsafe\n'
        fi
    else
        printf 'SKIP npm verification: not installed\n'
    fi
    _pds_consumer_uv || _pds_consumer_error 'UV eligibility/pruning failed; no forced fallback.'
}

storage_consumers() (
    set -euo pipefail
    export LC_ALL=C
    local consumer_mode="${1:-}" storage_user="${SUDO_USER:-${USER:-}}"
    local storage_account storage_uid storage_gid storage_home storage_cache
    local consumer_status=0 result base helper
    base=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd) || return 2
    helper="$base/storage_maintenance.sh"
    if [[ ! -r "$helper" ]]; then helper="$base/pds-storage-maintenance"; fi
    [[ -r "$helper" ]] || { printf 'ERROR missing PDS maintenance companion\n' >&2; return 2; }
    # shellcheck source=storage_maintenance.sh
    source "$helper"
    case "$consumer_mode" in
        audit-docker|cleanup-docker|audit-user|cleanup-user) shift ;;
        *) _pds_storage_error 'Usage: storage_consumers.sh audit-docker|cleanup-docker|audit-user|cleanup-user --user USER'; return 2 ;;
    esac
    [[ $# == 2 && "$1" == --user ]] || { _pds_storage_error 'Expected --user USER'; return 2; }
    storage_user="$2"
    _pds_storage_require getent id realpath stat timeout du find jq || return 2
    _pds_storage_context || return 2
    case "$consumer_mode" in
        *-docker)
            [[ "$(id -u)" == 0 ]] || { _pds_storage_error 'Docker retention/audit requires root.'; return 2; }
            _pds_consumer_docker_audit || consumer_status=2
            if [[ "$consumer_mode" == cleanup-docker && "$consumer_status" != 2 ]] &&
                command -v docker >/dev/null; then
                _pds_consumer_docker buildx prune --builder default --max-used-space 20000000000 \
                    --reserved-space 10000000000 --force ||
                    _pds_consumer_error 'Native Docker build-cache retention failed.'
                _pds_consumer_docker image prune --all --filter until=168h --force ||
                    _pds_consumer_error 'Native Docker image retention failed.'
                _pds_consumer_docker_audit || consumer_status=2
            fi
            ;;
        *-user)
            [[ "$(id -u)" == "$storage_uid" ]] || { _pds_storage_error 'Run user maintenance as the selected non-root account.'; return 2; }
            if _pds_consumer_user_audit; then :; else
                result=$?
                if (( result > consumer_status )); then consumer_status="$result"; fi
            fi
            if [[ "$consumer_mode" == cleanup-user ]]; then
                _pds_consumer_cleanup_user
                if _pds_consumer_user_audit; then :; else
                    result=$?
                    if (( result > consumer_status )); then consumer_status="$result"; fi
                fi
            fi
            ;;
    esac
    printf 'INFO consumer operation complete: mode=%s status=%s (0 healthy, 1 warning, 2 incomplete/error)\n' "$consumer_mode" "$consumer_status"
    return "$consumer_status"
)

if [[ "${BASH_SOURCE[0]:-}" == "$0" ]]; then
    storage_consumers "$@"
fi
