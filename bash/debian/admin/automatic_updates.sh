#!/bin/bash
# Select the PDS nightly policy without embedding it in every consumer script.
update_system_cron_entry() {
    local asset work staged mode uid gid
    local legacy='0 0 * * * root apt update -y && apt upgrade -y'
    if [[ $# -ne 0 ]]; then
        printf '%s\n' 'Usage: update_system_cron_entry' >&2
        return 2
    fi
    if ! command -v apt-get >/dev/null || [[ ! -x /usr/sbin/cron ]]; then
        printf '%s\n' 'Install APT and cron before configuring automatic updates.' >&2
        return 1
    fi
    asset="$(dirname -- "${BASH_SOURCE[0]}")/../../config/pds-update.sh"
    if [[ ! -r "$asset" ]] || ! bash -n "$asset"; then
        printf '%s\n' 'The PDS updater asset is missing or invalid; use the package or a complete checkout.' >&2
        return 1
    fi
    work="$(mktemp -d)" || return 1
    cat > "$work/cron" <<'EOF'
# Managed by PDS update_system_cron_entry.
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
0 0 * * * root /usr/local/sbin/pds-update >> /var/log/pds-update.log 2>&1
EOF
    if ! sudo install -d -m 0755 /usr/local/sbin /etc/cron.d ||
       ! sudo install -m 0755 -o root -g root -- "$asset" /usr/local/sbin/pds-update ||
       ! sudo install -m 0644 -o root -g root -- "$work/cron" /etc/cron.d/pds-update; then
        rm -rf -- "$work"
        return 1
    fi
    # Migrate only the exact job emitted by the earlier version of this helper.
    if [[ -f /etc/crontab ]] && sudo grep -Fxq -- "$legacy" /etc/crontab; then
        if [[ ! -e /etc/crontab.pds-backup ]]; then
            sudo cp -p -- /etc/crontab /etc/crontab.pds-backup || { rm -rf -- "$work"; return 1; }
        fi
        if ! (set -o pipefail; sudo awk -v legacy="$legacy" '$0 != legacy' /etc/crontab | cat > "$work/crontab"); then
            rm -rf -- "$work"
            return 1
        fi
        mode="$(stat -c %a /etc/crontab)"
        uid="$(stat -c %u /etc/crontab)"
        gid="$(stat -c %g /etc/crontab)"
        staged="$(sudo mktemp /etc/.pds-crontab.XXXXXX)" || { rm -rf -- "$work"; return 1; }
        if ! sudo install -m "$mode" -o "$uid" -g "$gid" -- "$work/crontab" "$staged" ||
           ! sudo mv -f -- "$staged" /etc/crontab; then
            sudo rm -f -- "$staged"
            rm -rf -- "$work"
            return 1
        fi
    fi
    if command -v systemctl >/dev/null; then
        sudo systemctl enable cron || { rm -rf -- "$work"; return 1; }
    fi
    rm -rf -- "$work"
    printf '%s\n' 'Nightly updates configured for 00:00. Start cron explicitly if it is not already running.'
}
