# Maintenance guard-rails

Reusable functions that keep a dev machine's disk healthy and recover it when it
isn't. Written to be sourced individually, the same way as the rest of PDS:

```bash
source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/common/maintenance/btrfs_guard.sh)
source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/common/maintenance/docker_cleanup.sh)
source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/common/maintenance/tmp_cleanup.sh)
```

## Why this exists

A dev host (btrfs root, RAID1 metadata across a small SSD + a larger NVMe) wedged:
writes stalled and it dropped off the network, while `df` still showed free space.

Root cause — the **btrfs metadata-allocation deadlock**:

- Metadata is `RAID1`, so a new metadata chunk needs a free slot on **two**
  devices at once.
- The **smaller** device fills its *allocation* first. Once it has ~0
  unallocated space, metadata can no longer grow — even though the other device
  and the data area still have room.
- When the last metadata slack is used, the filesystem flips read-only. Anything
  that writes (tailscaled, docker, logins) then fails.

It is invisible to `df` (which shows data free space) and only shows up in
`btrfs filesystem usage` as a device at `Unallocated: 0.00B` with metadata near
100%.

What filled it: ~130 GiB of reclaimable container cruft (build cache, dangling
images, 124 unused volumes), a disk-backed `/tmp` that grew to ~94 GiB of
killed-run scratch, and daily btrbk snapshots pinning all of it.

## Functions

### `btrfs_guard.sh`
| Function | Purpose |
|---|---|
| `btrfs_headroom_check [mnt] [min_gib] [meta_warn%]` | Detect the pre-deadlock state early. Returns 0/1/2 for OK/warn/critical — use in monitoring. |
| `btrfs_maintenance_balance [mnt]` | Light `-dusage/-musage` compaction that keeps per-device headroom. Cheap. |
| `install_btrfs_maintenance_timer [mnt]` | systemd weekly timer running the above automatically — the real "never again". |
| `btrfs_rescue_metadata <full_devid> [mnt] [scratch_dir] [gib] [drain]` | Recover a filesystem that has ALREADY deadlocked: attach a loop scratch device, drain the full device, remove the scratch. Never leaves the scratch attached (that would break boot). |

### `docker_cleanup.sh`
| Function | Purpose |
|---|---|
| `docker_disk_report` | Show reclaimable space and which named volumes are protected (in use). |
| `docker_safe_prune -k "vol1 vol2"` | Reclaim cache/images/stopped containers/unused volumes while protecting a keep-list (e.g. your database volume). |

### `tmp_cleanup.sh`
| Function | Purpose |
|---|---|
| `tmp_age_out [days] [--apply]` | Remove old, not-in-use `/tmp` entries (dry-run by default). |
| `install_tmp_cleanup_policy [days]` | systemd-tmpfiles rule so `/tmp` self-cleans and can't pile up again. |

## Recommended baseline on a new dev machine

```bash
install_btrfs_maintenance_timer /          # keep allocation headroom
install_tmp_cleanup_policy 10              # stop /tmp bloat
# optional monitoring: btrfs_headroom_check in a cron/alert
```

## Emergency: filesystem already read-only / stalled

```bash
# identify the full device (Unallocated ~ 0):
sudo btrfs device usage /
# scratch_dir must be on a DIFFERENT, non-full filesystem with free space:
btrfs_rescue_metadata 1 / /srv/bulk 20 8
```
