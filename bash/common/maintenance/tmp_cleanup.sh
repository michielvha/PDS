#!/bin/bash
# shellcheck disable=SC2016
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/common/maintenance/tmp_cleanup.sh) `
#
# Keep /tmp from silently growing. Killed CI/review/test runs leave scratch
# directories behind; on a disk-backed /tmp these accumulate to tens of GiB and
# (if /tmp is snapshotted) get pinned into backups. These helpers age-out old
# /tmp entries and install systemd-tmpfiles so it never piles up again.

# Function: tmp_age_out
# Description: Remove top-level entries in /tmp older than N days that have no
#   open file handles. Dry-run by default; pass --apply to delete.
# Usage: tmp_age_out [days] [--apply]
tmp_age_out() {
    local days=3 apply=0
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --apply) apply=1; shift ;;
            ''|*[!0-9]*) echo "tmp_age_out: bad arg '$1' (expected days and/or --apply)" >&2; return 1 ;;
            *) days="$1"; shift ;;
        esac
    done
    local target total=0
    echo "== tmp_age_out: entries in /tmp older than ${days}d (apply=$apply) =="
    while IFS= read -r -d '' target; do
        # skip anything with an open fd
        if sudo lsof +D "$target" >/dev/null 2>&1; then
            echo "   in-use, skip: $target"; continue
        fi
        local sz; sz=$(sudo du -sh "$target" 2>/dev/null | cut -f1)
        if [[ $apply -eq 1 ]]; then
            sudo rm -rf -- "$target" && echo "   removed ($sz): $target"
        else
            echo "   would remove ($sz): $target"
        fi
        total=$((total+1))
    done < <(sudo find /tmp -mindepth 1 -maxdepth 1 -mtime +"$days" -print0 2>/dev/null)
    echo "   $total candidate(s). Re-run with --apply to delete."
}

# Function: install_tmp_cleanup_policy
# Description: Install a systemd-tmpfiles rule so the system auto-clears /tmp
#   entries older than N days (default 10) on a schedule. Idempotent.
# Usage: install_tmp_cleanup_policy [days]
install_tmp_cleanup_policy() {
    local days="${1:-10}"
    echo "Installing /tmp age-out policy (${days}d) via systemd-tmpfiles ..."
    # 'D' manages /tmp; final field is the max-age for cleanup.
    echo "D /tmp 1777 root root ${days}d" | sudo tee /etc/tmpfiles.d/pds-tmp-cleanup.conf >/dev/null
    sudo systemctl enable --now systemd-tmpfiles-clean.timer 2>/dev/null
    echo "Active policy:"; cat /etc/tmpfiles.d/pds-tmp-cleanup.conf
    echo "Note: tmpfiles will act on the NEXT clean cycle; 'systemd-tmpfiles --clean' runs it now."
}
