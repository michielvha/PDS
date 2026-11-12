#!/bin/bash
# Managed by PDS storage maintenance.

_pds_storage_error() {
    printf 'ERROR %s\n' "$*" >&2
    return 2
}

_pds_storage_require() {
    local tool
    for tool in "$@"; do
        command -v "$tool" >/dev/null || {
            _pds_storage_error "Required tool is missing: $tool"
            return 2
        }
    done
}

_pds_storage_number() {
    [[ "$1" =~ ^[0-9]+$ && ${#1} -le 18 ]] || {
        _pds_storage_error "Invalid byte count: $1"
        return 2
    }
}

_pds_storage_context() {
    local record _password _gecos _shell pattern
    pattern='^[a-z_][a-z0-9_-]*[$]?$'
    [[ "$storage_user" =~ $pattern ]] || {
        _pds_storage_error 'A valid non-root --user is required.'
        return 2
    }
    record=$(getent passwd "$storage_user") || {
        _pds_storage_error "Cannot resolve user: $storage_user"
        return 2
    }
    IFS=: read -r storage_account _password storage_uid storage_gid _gecos storage_home _shell <<<"$record"
    [[ "$storage_account" == "$storage_user" && "$storage_uid" =~ ^[0-9]+$ &&
       "$storage_gid" =~ ^[0-9]+$ && "$storage_uid" != 0 && "$storage_home" == /* &&
       -d "$storage_home" && ! -L "$storage_home" ]] || {
        _pds_storage_error 'Invalid account or home directory.'
        return 2
    }
    [[ "$(realpath -e -- "$storage_home")" == "$storage_home" ]] || {
        _pds_storage_error 'Home must be a canonical directory, not an alias.'
        return 2
    }
    storage_cache="$storage_home/.cache/go-build"
}

_pds_storage_cache_path() {
    [[ -d "$storage_cache" && ! -L "$storage_home/.cache" && ! -L "$storage_cache" ]] || {
        _pds_storage_error 'The Go cache must be a real directory, without cache-path symlinks.'
        return 2
    }
    [[ "$(realpath -e -- "$storage_cache")" == "$storage_cache" &&
       "$(stat -c %u -- "$storage_cache")" == "$storage_uid" ]] || {
        _pds_storage_error 'The Go cache path or ownership is unsafe.'
        return 2
    }
    [[ "$(findmnt -rn -o FSTYPE -T "$storage_cache")" == btrfs ]] || {
        _pds_storage_error 'The Go cache must be on Btrfs.'
        return 2
    }
}

_pds_storage_prepared() {
    local inode device parent_device target
    _pds_storage_cache_path || return 2
    inode=$(stat -c %i -- "$storage_cache") || return 2
    device=$(stat -c %d -- "$storage_cache") || return 2
    parent_device=$(stat -c %d -- "$storage_home/.cache") || return 2
    target=$(findmnt -rn -o TARGET -T "$storage_cache") || return 2
    # Btrfs subvolume roots have inode 256 and a distinct anonymous device ID.
    if [[ "$inode" != 256 || "$device" == "$parent_device" || "$target" == "$storage_cache" ]]; then
        _pds_storage_error 'The Go cache must be a dedicated nested subvolume, not a directory or mount alias.'
        return 2
    fi
}

_pds_storage_size() {
    local output bytes _remainder
    output=$(du -sb -- "$1") || {
        _pds_storage_error "Cannot measure cache: $1"
        return 2
    }
    read -r bytes _remainder <<<"$output"
    _pds_storage_number "$bytes" || return 2
    printf '%s\n' "$bytes"
}

_pds_storage_notify() {
    local user="$1" uid="$2" message="$3" runtime="${4:-/run/user/$2}"
    if [[ ! -S "$runtime/bus" ]]; then
        printf 'SKIP desktop notification: no active user bus for %s\n' "$user"
        return 0
    fi
    if ! command -v notify-send >/dev/null; then
        printf 'SKIP desktop notification: notify-send is unavailable\n'
        return 0
    fi
    if ! runuser -u "$user" -- env XDG_RUNTIME_DIR="$runtime" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=$runtime/bus" \
        notify-send --app-name=PDS 'Storage maintenance warning' "$message"; then
        _pds_storage_error 'Desktop notification failed; the storage warning remains in the journal.'
        return 2
    fi
    printf 'OK desktop notification submitted for %s\n' "$user"
}

_pds_storage_check() {
    local usage metrics kind first second status=0 total=0 available=0
    local bytes browser_bytes=0 cache path metadata_used metadata_size
    [[ "$(id -u)" == 0 ]] || {
        _pds_storage_error 'check requires root for complete Btrfs measurements.'
        return 2
    }
    _pds_storage_require btrfs findmnt du stat awk || return 2
    [[ "$(findmnt -rn -o FSTYPE -T "$storage_mount")" == btrfs ]] || {
        _pds_storage_error "Not a readable Btrfs mount: $storage_mount"
        return 2
    }
    usage=$(btrfs filesystem usage -b "$storage_mount") || {
        _pds_storage_error 'Btrfs usage measurement failed.'
        return 2
    }
    metrics=$(printf '%s\n' "$usage" | awk '
        function value(label, line, part) {
            if (!index(line, label)) return ""
            part=substr(line, index(line, label)+length(label))
            sub(/^[[:space:]]*/, "", part)
            if (part !~ /^[0-9]+([,[:space:]]|$)/) return ""
            sub(/[^0-9].*$/, "", part)
            return part
        }
        /^[[:space:]]*Device size:/ {total=value("Device size:", $0)}
        /^[[:space:]]*Device missing:/ {missing=value("Device missing:", $0)}
        /^[[:space:]]*Free \(statfs, df\):/ {free=value("Free (statfs, df):", $0)}
        /^[[:space:]]*Metadata,/ {
            size=value("Size:", $0); used=value("Used:", $0)
            if (size=="" || used=="") invalid=1
            metadata_size+=size; metadata_used+=used
        }
        /^Unallocated:/ {unallocated=1; next}
        unallocated && NF {
            if (NF!=2 || $1 !~ /^\/dev\// || $2 !~ /^[0-9]+$/) invalid=1
            else {devices[++count]=$1; bytes[count]=$2}
        }
        END {
            if (invalid || total=="" || total<=0 || free=="" || free>total ||
                missing=="" || missing!=0 || metadata_size<=0 ||
                metadata_used>metadata_size || count==0) exit 2
            printf "TOTAL %.0f\nFREE %.0f\nMETA %.0f %.0f\n", total, free, metadata_size, metadata_used
            for (i=1; i<=count; i++) printf "DEVICE %s %.0f\n", devices[i], bytes[i]
        }') || {
        _pds_storage_error 'Incomplete, degraded or malformed Btrfs byte measurements.'
        return 2
    }
    if ! btrfs device stats -c "$storage_mount"; then
        _pds_storage_error 'Device counters report errors or cannot be read.'
        return 2
    fi
    while read -r kind first second; do
        case "$kind" in
            TOTAL) total="$first" ;;
            FREE) available="$first" ;;
            META) metadata_size="$first"; metadata_used="$second" ;;
            DEVICE)
                _pds_storage_number "$second" || return 2
                printf 'INFO allocation headroom: %s bytes=%s\n' "$first" "$second"
                if (( second < 8589934592 )); then
                    printf 'WARN %s is below the 8 GiB allocation reserve\n' "$first"
                    status=1
                fi
                ;;
        esac
    done <<<"$metrics"
    printf 'INFO filesystem available_bytes=%s total_bytes=%s metadata_used_bytes=%s metadata_size_bytes=%s\n' \
        "$available" "$total" "$metadata_used" "$metadata_size"
    if awk -v free="$available" -v total="$total" 'BEGIN {exit !(free/total < 0.10)}'; then
        printf 'WARN filesystem has less than 10 percent available space\n'
        status=1
    fi
    if [[ -e "$storage_cache" || -L "$storage_cache" ]]; then
        _pds_storage_cache_path || return 2
        bytes=$(_pds_storage_size "$storage_cache") || return 2
        printf 'INFO Go cache apparent_bytes=%s\n' "$bytes"
        if (( bytes > 21474836480 )); then
            printf 'WARN Go cache exceeds 20 GiB\n'
            status=1
        fi
    else
        printf 'SKIP Go cache: directory is absent\n'
    fi
    for cache in ms-playwright ms-playwright-mcp puppeteer; do
        path="$storage_home/.cache/$cache"
        if [[ ! -e "$path" && ! -L "$path" ]]; then
            printf 'SKIP browser cache: %s is absent\n' "$cache"
            continue
        fi
        [[ -d "$path" && ! -L "$storage_home/.cache" && ! -L "$path" ]] || {
            _pds_storage_error "Unsafe browser-cache path: $path"
            return 2
        }
        bytes=$(_pds_storage_size "$path") || return 2
        browser_bytes=$((browser_bytes + bytes))
    done
    printf 'INFO browser caches apparent_bytes=%s\n' "$browser_bytes"
    if (( browser_bytes > 16106127360 )); then
        printf 'WARN combined browser caches exceed 15 GiB; no browser will be deleted\n'
        status=1
    fi
    if (( status != 0 )); then
        _pds_storage_notify "$storage_user" "$storage_uid" \
            'PDS detected storage pressure. Inspect pds-btrfs-headroom.service in the system journal.' || return 2
    else
        printf 'OK storage measurements are within policy\n'
    fi
    return "$status"
}

_pds_storage_go() {
    [[ "$(id -u)" == "$storage_uid" ]] || {
        _pds_storage_error "Run Go cache operations as $storage_user, not root or another account."
        return 2
    }
    if [[ -z "$storage_go" ]]; then
        storage_go=$(command -v go) || {
            _pds_storage_error 'Go is missing; supply its existing absolute path with --go.'
            return 2
        }
    fi
    [[ "$storage_go" == /* && -x "$storage_go" ]] || {
        _pds_storage_error 'An existing absolute Go executable path is required.'
        return 2
    }
}

_pds_storage_busy() {
    local result
    if pgrep -u "$storage_uid" -x 'go|compile|link'; then
        printf 'WARN busy Go build; postpone cache maintenance\n'
        return 1
    else
        result=$?
        if [[ "$result" != 1 ]]; then
            _pds_storage_error 'Cannot determine whether Go builds are active.'
            return 2
        fi
    fi
}

_pds_storage_native_clean() {
    # Empty flags alone can fall back to settings in Go's persistent env file.
    GOENV=off GOFLAGS='' GOCACHE="$storage_cache" GOCACHEPROG='' \
        GOTOOLCHAIN=local "$storage_go" clean -cache
}

_pds_storage_cleanup_go() {
    local bytes remaining
    _pds_storage_require findmnt du stat pgrep find || return 2
    _pds_storage_go || return 2
    _pds_storage_prepared || return 2
    bytes=$(_pds_storage_size "$storage_cache") || return 2
    if (( bytes <= 21474836480 )); then
        printf 'SKIP Go cache below budget: apparent_bytes=%s limit_bytes=21474836480\n' "$bytes"
        return 0
    fi
    _pds_storage_busy || return $?
    _pds_storage_cache_contents || return 2
    if ! _pds_storage_native_clean; then
        _pds_storage_error 'Native Go cache cleanup failed.'
        return 2
    fi
    remaining=$(_pds_storage_size "$storage_cache") || return 2
    if (( remaining > 21474836480 )); then
        _pds_storage_error "Native cleanup completed but the cache remains over budget: $remaining"
        return 2
    fi
    printf 'OK native Go cleanup: before_bytes=%s after_bytes=%s\n' "$bytes" "$remaining"
}

_pds_storage_cache_contents() (
    local path relative directory name listing device
    device=$(stat -c %d -- "$storage_cache") || return 2
    listing=$(mktemp) || return 2
    trap 'rm -f -- "$listing"' EXIT
    if ! find "$storage_cache" -mindepth 1 -maxdepth 2 -xdev -print0 >"$listing"; then
        _pds_storage_error 'Cannot inspect all cache contents safely.'
        return 2
    fi
    while IFS= read -r -d '' path; do
        relative="${path#"$storage_cache"/}"
        [[ ! -L "$path" ]] || {
            _pds_storage_error "Refusing a cache symlink: $relative"
            return 2
        }
        case "$relative" in
            README|trim.txt|testexpire.txt)
                [[ -f "$path" ]] && continue
                ;;
            */*)
                directory="${relative%%/*}"
                name="${relative#*/}"
                if [[ "$directory" =~ ^[0-9a-f]{2}$ &&
                      "$name" =~ ^[0-9a-f]{64}-[ad]$ &&
                      "${name:0:2}" == "$directory" && -f "$path" ]]; then
                    continue
                fi
                ;;
            *)
                if [[ "$relative" =~ ^[0-9a-f]{2}$ && -d "$path" ]]; then
                    [[ "$(stat -c %d -- "$path")" == "$device" ]] || {
                        _pds_storage_error "Refusing a nested filesystem in the cache: $relative"
                        return 2
                    }
                    continue
                fi
                ;;
        esac
        _pds_storage_error "Unknown cache content; preserve it before preparation: $relative"
        return 2
    done <"$listing"
)

_pds_storage_prepare() (
    local inode scratch mode gid path configured_cache
    _pds_storage_require btrfs findmnt stat find pgrep mv || return 2
    _pds_storage_go || return 2
    _pds_storage_busy || return $?
    configured_cache=$(GOFLAGS=' ' GOCACHEPROG='' GOTOOLCHAIN=local "$storage_go" env GOCACHE) || {
        _pds_storage_error 'Cannot verify the existing Go cache configuration.'
        return 2
    }
    if [[ "$configured_cache" != "$storage_cache" ]]; then
        _pds_storage_error "Configured Go cache differs; no configuration was changed: $configured_cache"
        return 2
    fi
    if [[ -L "$storage_home/.cache" || -L "$storage_cache" ]]; then
        _pds_storage_error 'Refusing cache preparation through a symlink.'
        return 2
    fi
    mkdir -p -- "$storage_cache" || return 2
    _pds_storage_cache_path || return 2
    inode=$(stat -c %i -- "$storage_cache") || return 2
    if [[ "$inode" == 256 ]]; then
        _pds_storage_prepared || return 2
        printf 'SKIP Go cache is already a dedicated subvolume\n'
        return 0
    fi
    _pds_storage_cache_contents || return 2
    if ! _pds_storage_native_clean; then
        _pds_storage_error 'Native cache cleanup failed before preparation.'
        return 2
    fi
    _pds_storage_cache_contents || return 2
    mode=$(stat -c %a -- "$storage_cache") || return 2
    gid=$(stat -c %g -- "$storage_cache") || return 2
    scratch=$(mktemp -d "$storage_home/.cache/.pds-go-prepare.XXXXXX") || return 2
    trap 'printf "ERROR preparation interrupted; inspect preserved staging directory: %s\n" "$scratch" >&2' EXIT
    btrfs subvolume create "$scratch/fresh" || return 2
    chmod "$mode" "$scratch/fresh" || return 2
    chgrp "$gid" "$scratch/fresh" || return 2
    if ! find "$storage_cache" -mindepth 1 -depth -print0 >"$scratch/entries"; then
        _pds_storage_error 'Cache traversal failed during preparation.'
        return 2
    fi
    while IFS= read -r -d '' path; do
        if [[ -d "$path" && ! -L "$path" ]]; then
            rmdir -- "$path" || return 2
        else
            case "${path##*/}" in
                README|trim.txt|testexpire.txt) rm -- "$path" || return 2 ;;
                *)
                    _pds_storage_error 'Cache changed during preparation; no replacement was performed.'
                    return 2
                    ;;
            esac
        fi
    done <"$scratch/entries"
    # Rename can replace only an empty directory; concurrent writers make it fail.
    mv -T --no-copy -- "$scratch/fresh" "$storage_cache" || return 2
    rm -- "$scratch/entries" || return 2
    rmdir -- "$scratch" || return 2
    trap - EXIT
    _pds_storage_prepared || return 2
    printf 'OK Go cache prepared as a nested subvolume: %s\n' "$storage_cache"
)

_pds_storage_unit_arg() {
    local value="$1"
    [[ "$value" != *$'\n'* && "$value" != *$'\r'* ]] || {
        _pds_storage_error 'Newlines cannot be represented in managed unit arguments.'
        return 2
    }
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    value="${value//%/%%}"
    printf '"%s"' "$value"
}

_pds_storage_owned() {
    local file="$1" uid="$2" identity="${3:-}"
    if [[ ! -e "$file" && ! -L "$file" ]]; then
        return 0
    fi
    if [[ ! -f "$file" || -L "$file" || "$(stat -c %u -- "$file")" != "$uid" ]] ||
        ! grep -Fxq '# Managed by PDS storage maintenance.' "$file"; then
        _pds_storage_error "Refusing a conflicting file: $file"
        return 2
    fi
    if [[ -n "$identity" ]]; then
        if ! grep -Fxq "# PDS user: $storage_user" "$file" ||
            ! grep -Fxq "# PDS mount: $storage_mount" "$file"; then
            _pds_storage_error "Existing configuration differs; do not overwrite it: $file"
            return 2
        fi
    fi
}

_pds_storage_userctl() {
    runuser -u "$storage_user" -- env HOME="$storage_home" \
        XDG_RUNTIME_DIR="/run/user/$storage_uid" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$storage_uid/bus" \
        systemctl --user "$@"
}

_pds_storage_units() {
    storage_program=/usr/local/libexec/pds-storage-maintenance
    storage_root_service=/etc/systemd/system/pds-btrfs-headroom.service
    storage_root_timer=/etc/systemd/system/pds-btrfs-headroom.timer
    storage_user_dir="$storage_home/.config/systemd/user"
    storage_user_service="$storage_user_dir/pds-go-cache-clean.service"
    storage_user_timer="$storage_user_dir/pds-go-cache-clean.timer"
    storage_wanted="$storage_user_dir/timers.target.wants/pds-go-cache-clean.timer"
    storage_consumer_program=/usr/local/libexec/pds-storage-consumers
    _pds_storage_owned "$storage_program" 0 || return 2
    _pds_storage_owned "$storage_root_service" 0 identity || return 2
    _pds_storage_owned "$storage_root_timer" 0 identity || return 2
    _pds_storage_owned "$storage_user_service" "$storage_uid" identity || return 2
    _pds_storage_owned "$storage_user_timer" "$storage_uid" identity || return 2
    if [[ -e "$storage_wanted" || -L "$storage_wanted" ]]; then
        [[ -L "$storage_wanted" && "$(realpath -e -- "$storage_wanted")" == "$storage_user_timer" ]] || {
            _pds_storage_error "Refusing an unrelated enabled timer: $storage_wanted"
            return 2
        }
    fi
    _pds_storage_owned "$storage_consumer_program" 0 || return 2
    local role suffix file wanted
    for role in docker user; do
        for suffix in service timer; do
            if [[ "$role" == docker ]]; then
                file="/etc/systemd/system/pds-cache-$role.$suffix"
                _pds_storage_owned "$file" 0 identity || return 2
            else
                file="$storage_user_dir/pds-cache-$role.$suffix"
                _pds_storage_owned "$file" "$storage_uid" identity || return 2
            fi
        done
    done
    wanted="$storage_user_dir/timers.target.wants/pds-cache-user.timer"
    if [[ -e "$wanted" || -L "$wanted" ]]; then
        [[ -L "$wanted" && "$(realpath -e -- "$wanted")" == "$storage_user_dir/pds-cache-user.timer" ]] || {
            _pds_storage_error "Refusing an unrelated daily user timer: $wanted"
            return 2
        }
    fi
}

_pds_storage_work_cleanup() {
    local work="$1"
    rm -f -- "$work/root.service" "$work/root.timer" "$work/user.service" "$work/user.timer" || return 2
    rm -f -- "$work/docker-daily.service" "$work/docker-daily.timer" \
        "$work/user-daily.service" "$work/user-daily.timer" || return 2
    rmdir -- "$work"
}

_pds_storage_install() (
    local work source_file consumer_source go_arg mount_arg role calendar file no_new_privileges service_path
    [[ "$(id -u)" == 0 ]] || {
        _pds_storage_error 'install requires root.'
        return 2
    }
    _pds_storage_require install systemctl runuser btrfs stat grep jq timeout || return 2
    [[ -n "$storage_go" && "$storage_go" == /* && -x "$storage_go" ]] || {
        _pds_storage_error 'install needs --go with the existing stable Go executable path.'
        return 2
    }
    _pds_storage_prepared || return 2
    storage_mount=$(realpath -e -- "$storage_mount") || return 2
    _pds_storage_units || return 2
    source_file=$(realpath -e -- "${BASH_SOURCE[0]}") || return 2
    consumer_source="$(dirname -- "$source_file")/storage_consumers.sh"
    if [[ "$source_file" == "$storage_program" ]]; then consumer_source="$storage_consumer_program"; fi
    [[ -r "$consumer_source" && ! -L "$consumer_source" ]] || {
        _pds_storage_error 'The consumer companion is missing; install from a complete checkout.'
        return 2
    }
    bash -n "$consumer_source" || return 2
    bash -n "$source_file" || return 2
    go_arg=$(_pds_storage_unit_arg "$storage_go") || return 2
    mount_arg=$(_pds_storage_unit_arg "$storage_mount") || return 2
    work=$(mktemp -d) || return 2
    trap '_pds_storage_work_cleanup "$work"' EXIT
    chmod 0755 "$work" || return 2
    # The ':' exec prefix keeps configured paths literal to systemd.
    cat >"$work/root.service" <<EOF
# Managed by PDS storage maintenance.
# PDS user: $storage_user
# PDS mount: $storage_mount
[Unit]
Description=PDS read-only Btrfs headroom check
RequiresMountsFor=$mount_arg
[Service]
Type=oneshot
ExecStart=:/usr/bin/bash $storage_program check --user $storage_user --mount $mount_arg
Environment=PATH=/usr/sbin:/usr/bin:/sbin:/bin
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=read-only
TimeoutStartSec=120
EOF
    cat >"$work/root.timer" <<EOF
# Managed by PDS storage maintenance.
# PDS user: $storage_user
# PDS mount: $storage_mount
[Unit]
Description=Check PDS storage headroom hourly
[Timer]
OnCalendar=hourly
Persistent=true
[Install]
WantedBy=timers.target
EOF
    cat >"$work/user.service" <<EOF
# Managed by PDS storage maintenance.
# PDS user: $storage_user
# PDS mount: $storage_mount
[Unit]
Description=PDS native Go build-cache cleanup
[Service]
Type=oneshot
ExecStart=:/usr/bin/bash $storage_program cleanup-go --user $storage_user --go $go_arg
NoNewPrivileges=true
PrivateTmp=true
Nice=10
IOSchedulingClass=idle
TimeoutStartSec=15min
EOF
    cat >"$work/user.timer" <<EOF
# Managed by PDS storage maintenance.
# PDS user: $storage_user
# PDS mount: $storage_mount
[Unit]
Description=Check the PDS Go cache budget every four hours
[Timer]
OnCalendar=*-*-* 00/4:15:00
Persistent=true
[Install]
WantedBy=timers.target
EOF
    for role in docker user; do
        if [[ "$role" == docker ]]; then
            calendar='*-*-* 04:45:00'; no_new_privileges=true
            service_path=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
        else
            calendar='*-*-* 05:15:00'; no_new_privileges=false
            service_path="/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$storage_home/.local/bin"
        fi
        cat >"$work/$role-daily.service" <<EOF
# Managed by PDS storage maintenance.
# PDS user: $storage_user
# PDS mount: $storage_mount
[Unit]
Description=PDS $role native cache retention and storage audit
[Service]
Type=oneshot
ExecStart=:/usr/bin/bash $storage_consumer_program cleanup-$role --user $storage_user
Environment=PATH=$service_path
NoNewPrivileges=$no_new_privileges
Nice=10
IOSchedulingClass=idle
TimeoutStartSec=30min
EOF
        cat >"$work/$role-daily.timer" <<EOF
# Managed by PDS storage maintenance.
# PDS user: $storage_user
# PDS mount: $storage_mount
[Unit]
Description=PDS daily $role cache retention
[Timer]
OnCalendar=$calendar
Persistent=true
[Install]
WantedBy=timers.target
EOF
    done
    chmod 0644 "$work/root.service" "$work/root.timer" \
        "$work/user.service" "$work/user.timer" "$work/docker-daily.service" \
        "$work/docker-daily.timer" "$work/user-daily.service" "$work/user-daily.timer" || return 2
    systemd-analyze verify "$work/root.service" "$work/root.timer" \
        "$work/user.service" "$work/user.timer" "$work/docker-daily.service" \
        "$work/docker-daily.timer" "$work/user-daily.service" "$work/user-daily.timer" || return 2
    install -d -m 0755 /usr/local/libexec || return 2
    if [[ "$source_file" != "$storage_program" ]]; then
        install -m 0755 -o root -g root -- "$source_file" "$storage_program" || return 2
    fi
    if [[ "$consumer_source" != "$storage_consumer_program" ]]; then
        install -m 0755 -o root -g root -- "$consumer_source" "$storage_consumer_program" || return 2
    fi
    install -m 0644 -o root -g root -- "$work/root.service" "$storage_root_service" || return 2
    install -m 0644 -o root -g root -- "$work/root.timer" "$storage_root_timer" || return 2
    runuser -u "$storage_user" -- install -d -m 0755 "$storage_user_dir/timers.target.wants" || return 2
    runuser -u "$storage_user" -- install -m 0644 -- "$work/user.service" "$storage_user_service" || return 2
    runuser -u "$storage_user" -- install -m 0644 -- "$work/user.timer" "$storage_user_timer" || return 2
    if [[ ! -L "$storage_wanted" ]]; then
        runuser -u "$storage_user" -- ln -s ../pds-go-cache-clean.timer "$storage_wanted" || return 2
    fi
    for role in docker user; do
        for file in service timer; do
            if [[ "$role" == docker ]]; then
                install -m 0644 -o root -g root -- "$work/$role-daily.$file" \
                    "/etc/systemd/system/pds-cache-docker.$file" || return 2
            else
                runuser -u "$storage_user" -- install -m 0644 -- "$work/$role-daily.$file" \
                    "$storage_user_dir/pds-cache-user.$file" || return 2
            fi
        done
    done
    if [[ ! -L "$storage_user_dir/timers.target.wants/pds-cache-user.timer" ]]; then
        runuser -u "$storage_user" -- ln -s ../pds-cache-user.timer \
            "$storage_user_dir/timers.target.wants/pds-cache-user.timer" || return 2
    fi
    systemctl daemon-reload || return 2
    systemctl enable --now pds-btrfs-headroom.timer pds-cache-docker.timer || return 2
    if [[ -S "/run/user/$storage_uid/bus" ]]; then
        _pds_storage_userctl daemon-reload || return 2
        _pds_storage_userctl enable --now pds-go-cache-clean.timer pds-cache-user.timer || return 2
    else
        printf 'SKIP starting user timer: enabled for the next login; lingering was not changed\n'
    fi
    printf 'OK installed hourly Btrfs checks, four-hour Go cleanup and daily native consumer retention/audits\n'
)

_pds_storage_uninstall() {
    local file
    [[ "$(id -u)" == 0 ]] || {
        _pds_storage_error 'uninstall requires root.'
        return 2
    }
    _pds_storage_units || return 2
    if [[ -f "$storage_root_timer" ]]; then
        systemctl disable --now pds-btrfs-headroom.timer || return 2
    fi
    if [[ -f "$storage_root_service" ]]; then
        systemctl stop pds-btrfs-headroom.service || return 2
    fi
    if [[ -f /etc/systemd/system/pds-cache-docker.timer ]]; then
        systemctl disable --now pds-cache-docker.timer || return 2
        systemctl stop pds-cache-docker.service || return 2
    fi
    if [[ -S "/run/user/$storage_uid/bus" ]]; then
        if [[ -f "$storage_user_timer" ]]; then
            _pds_storage_userctl disable --now pds-go-cache-clean.timer || return 2
        fi
        if [[ -f "$storage_user_service" ]]; then
            _pds_storage_userctl stop pds-go-cache-clean.service || return 2
        fi
        if [[ -f "$storage_user_dir/pds-cache-user.timer" ]]; then
            _pds_storage_userctl disable --now pds-cache-user.timer || return 2
            _pds_storage_userctl stop pds-cache-user.service || return 2
        fi
    fi
    for file in "$storage_wanted" "$storage_user_timer" "$storage_user_service"; do
        runuser -u "$storage_user" -- rm -f -- "$file" || return 2
    done
    runuser -u "$storage_user" -- rm -f -- \
        "$storage_user_dir/timers.target.wants/pds-cache-user.timer" \
        "$storage_user_dir/pds-cache-user.timer" "$storage_user_dir/pds-cache-user.service" || return 2
    rm -f -- /etc/systemd/system/pds-cache-docker.timer \
        /etc/systemd/system/pds-cache-docker.service "$storage_consumer_program" || return 2
    rm -f -- "$storage_root_timer" "$storage_root_service" "$storage_program" || return 2
    systemctl daemon-reload || return 2
    if [[ -S "/run/user/$storage_uid/bus" ]]; then
        _pds_storage_userctl daemon-reload || return 2
    fi
    printf 'OK removed only PDS units and program; cache subvolume and data remain\n'
}

storage_maintenance() (
    set -euo pipefail
    export LC_ALL=C
    local mode="${1:-}" storage_user="${SUDO_USER:-${USER:-}}" storage_mount=/
    local storage_go='' storage_account storage_uid storage_gid storage_home storage_cache
    local storage_program storage_root_service storage_root_timer storage_user_dir
    local storage_user_service storage_user_timer storage_wanted storage_consumer_program
    case "$mode" in
        --help|-h|help)
            printf '%s\n' \
                'Usage: storage_maintenance.sh MODE --user USER [--mount PATH] [--go /absolute/go]' \
                'Modes: check, cleanup-go, prepare-go-cache, install, uninstall' \
                'check/install/uninstall require root; Go operations run as the selected user.' \
                'Defaults: Go budget 20 GiB; device reserve 8 GiB; free-space warning 10%; browser budget 15 GiB.'
            return 0
            ;;
        check|cleanup-go|prepare-go-cache|install|uninstall) shift ;;
        *) _pds_storage_error 'Choose check, cleanup-go, prepare-go-cache, install or uninstall.'; return 2 ;;
    esac
    while (( $# )); do
        [[ $# -ge 2 ]] || { _pds_storage_error "Missing value for $1"; return 2; }
        case "$1" in
            --user) storage_user="$2" ;;
            --mount) storage_mount="$2" ;;
            --go) storage_go="$2" ;;
            *) _pds_storage_error "Unknown option: $1"; return 2 ;;
        esac
        shift 2
    done
    _pds_storage_require uname getent id realpath || return 2
    [[ "$(uname -s)" == Linux ]] || { _pds_storage_error 'Linux is required.'; return 2; }
    _pds_storage_context || return 2
    case "$mode" in
        check) _pds_storage_check ;;
        cleanup-go) _pds_storage_cleanup_go ;;
        prepare-go-cache) _pds_storage_prepare ;;
        install) _pds_storage_install ;;
        uninstall) _pds_storage_uninstall ;;
    esac
)

if [[ "${BASH_SOURCE[0]:-}" == "$0" ]]; then
    storage_maintenance "$@"
fi
