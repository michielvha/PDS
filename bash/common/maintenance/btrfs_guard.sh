#!/bin/bash
# shellcheck disable=SC2016
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/common/maintenance/btrfs_guard.sh) `
#
# Guard-rail functions for btrfs root filesystems on dev machines.
#
# Background: a multi-device btrfs with RAID1 metadata deadlocks when the
# SMALLEST device becomes 100% allocated: metadata needs a free slot on two
# devices at once to grow, so once the small device has 0 unallocated the FS
# can no longer allocate metadata and flips read-only ("ENOSPC"), even while
# `df` still shows free space. These helpers detect that condition early,
# keep headroom automatically, and recover a filesystem that has already hit it.

# Function: btrfs_headroom_check
# Description: Report per-device unallocated space and metadata usage for a btrfs
#   mount, and flag the pre-deadlock condition. Returns 0 = healthy, 1 = warning,
#   2 = critical. Intended for monitoring / cron / pre-flight checks.
# Usage: btrfs_headroom_check [mountpoint] [min_unallocated_gib] [meta_warn_pct]
btrfs_headroom_check() {
    local mnt="${1:-/}"
    local min_unalloc_gib="${2:-10}"
    local meta_warn_pct="${3:-90}"
    local rc=0

    if ! sudo btrfs filesystem df "$mnt" >/dev/null 2>&1; then
        echo "btrfs_headroom_check: $mnt is not a btrfs filesystem" >&2
        return 2
    fi

    # Metadata used-% parsed from "Metadata,RAID1: ... Used:X (Y%)".
    local meta_pct
    meta_pct=$(sudo btrfs filesystem usage "$mnt" | awk -F'[()%]' '/Metadata,/{print $2; exit}')
    meta_pct=${meta_pct:-0}

    echo "== btrfs headroom: $mnt =="
    echo "Metadata used: ${meta_pct}%  (warn >= ${meta_warn_pct}%)"

    # Per-device unallocated.
    local worst=99999 dev un
    while read -r dev un; do
        [[ -z "$dev" ]] && continue
        printf '  %-20s unallocated: %s GiB\n' "$dev" "$un"
        # integer GiB compare
        awk "BEGIN{exit !($un < $min_unalloc_gib)}" && rc=2
        awk "BEGIN{exit !($un < $worst)}" && worst=$un
    done < <(sudo btrfs device usage -g "$mnt" \
                | awk '/path|ID:/{d=$NF} /Unallocated/{gsub(/GiB/,"",$2); print d, $2+0}')

    # Metadata pressure is a warning on its own.
    awk "BEGIN{exit !($meta_pct >= $meta_warn_pct)}" && { [[ $rc -lt 1 ]] && rc=1; }

    case $rc in
        0) echo "status: OK" ;;
        1) echo "status: WARNING (metadata pressure) — schedule btrfs_maintenance_balance" >&2 ;;
        2) echo "status: CRITICAL — a device is below ${min_unalloc_gib} GiB unallocated; run btrfs_maintenance_balance now, or btrfs_rescue_metadata if already read-only" >&2 ;;
    esac
    return $rc
}

# Function: btrfs_maintenance_balance
# Description: Light, safe compaction that keeps unallocated headroom on every
#   device so the metadata-growth deadlock cannot occur. Only relocates
#   partially-empty block groups (-dusage/-musage), which is cheap. Run weekly.
# Usage: btrfs_maintenance_balance [mountpoint] [dusage] [musage]
btrfs_maintenance_balance() {
    local mnt="${1:-/}"
    local dusage="${2:-50}"
    local musage="${3:-50}"
    echo "btrfs_maintenance_balance: compacting $mnt (dusage<=$dusage, musage<=$musage)"
    sudo btrfs balance start -dusage="$dusage" -musage="$musage" "$mnt"
    echo "done"
    btrfs_headroom_check "$mnt"
}

# Function: install_btrfs_maintenance_timer
# Description: Install a systemd service + weekly timer that runs
#   btrfs_maintenance_balance on the given mount, so headroom is maintained
#   automatically. Idempotent.
# Usage: install_btrfs_maintenance_timer [mountpoint]
install_btrfs_maintenance_timer() {
    local mnt="${1:-/}"
    local dusage="${2:-50}"
    echo "Installing btrfs weekly maintenance timer for $mnt ..."
    sudo tee /etc/systemd/system/btrfs-maintenance.service >/dev/null <<EOF
[Unit]
Description=btrfs light maintenance balance (keep allocation headroom)
Documentation=https://github.com/michielvha/PDS

[Service]
Type=oneshot
Nice=19
IOSchedulingClass=idle
ExecStart=/sbin/btrfs balance start -dusage=${dusage} -musage=${dusage} ${mnt}
EOF
    sudo tee /etc/systemd/system/btrfs-maintenance.timer >/dev/null <<EOF
[Unit]
Description=Run btrfs light maintenance balance weekly

[Timer]
OnCalendar=Sun 03:30
Persistent=true
RandomizedDelaySec=30m

[Install]
WantedBy=timers.target
EOF
    sudo systemctl daemon-reload
    sudo systemctl enable --now btrfs-maintenance.timer
    systemctl status btrfs-maintenance.timer --no-pager | head -5
}

# Function: btrfs_rescue_metadata
# Description: Recover a btrfs filesystem that has ALREADY hit the metadata
#   deadlock (a device at 0 unallocated, metadata unable to grow, writes
#   stalling / read-only). Temporarily attaches a loop-backed scratch device so
#   metadata can allocate again, drains data off the full device to create real
#   unallocated space, then removes the scratch device and cleans up.
#   The scratch device is NEVER left attached (a loop file on another fs would
#   break boot), so this is safe to run and leaves a clean 2-device layout.
# Usage: btrfs_rescue_metadata <full_devid> [mountpoint] [scratch_dir] [scratch_gib] [drain_chunks]
#   e.g. btrfs_rescue_metadata 1 / /srv/bulk 20 8
btrfs_rescue_metadata() {
    local devid="$1"
    local mnt="${2:-/}"
    local scratch_dir="${3:-/srv/bulk}"
    local gib="${4:-20}"
    local drain="${5:-8}"
    if [[ -z "$devid" ]]; then
        echo "usage: btrfs_rescue_metadata <full_devid> [mnt] [scratch_dir] [gib] [drain_chunks]" >&2
        return 1
    fi
    local img="${scratch_dir}/.btrfs-rescue-scratch.img"
    local loop
    echo ">> btrfs_rescue_metadata: mnt=$mnt full devid=$devid scratch=${img} (${gib}G)"

    echo "1) create + attach scratch device"
    sudo fallocate -l "${gib}G" "$img" || return 1
    loop=$(sudo losetup --show -f "$img") || return 1
    echo "   loop=$loop"

    echo "2) add scratch to filesystem (breaks the metadata deadlock)"
    sudo btrfs device add -f "$loop" "$mnt" || { sudo losetup -d "$loop"; sudo rm -f "$img"; return 1; }

    echo "3) drain ~${drain} data chunks off the full device (devid $devid)"
    sudo btrfs balance start -ddevid="${devid}",limit="${drain}" "$mnt" \
        || echo "   (balance returned non-zero; continuing to remove scratch)"

    echo "4) remove scratch device (relocates its chunks back onto the real devices)"
    sudo btrfs device remove "$loop" "$mnt"

    echo "5) detach loop + delete image"
    sudo losetup -d "$loop" 2>/dev/null
    sudo rm -f "$img"

    echo ">> done — current layout:"
    sudo btrfs device usage "$mnt" | grep -E 'path|ID:|Unallocated'
    btrfs_headroom_check "$mnt"
}
