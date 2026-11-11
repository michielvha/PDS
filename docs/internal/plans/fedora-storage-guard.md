---
status: planned
status_description: "Owner accepted the reviewed scope and authorized scoped publication and verified Fedora installation."
issue: null
goal: "Reclaim over-budget Go build cache on a repeatable schedule without home snapshots retaining its discarded contents."
covers:
  - bash/fedora/storage_maintenance.sh
  - tests/test_storage_maintenance.py
  - docs/fedora-storage-guard.md
  - bash/readme.md
  - changelog.md
---

# Plan: Fedora storage guard

Make native Go cache cleanup repeatable and exclude rebuildable Go cache from
future home snapshots. Keep scheduled filesystem monitoring read-only.

## Context

### Owner summary

Fedora's root and home share a two-device Btrfs filesystem. During the failure,
metadata was RAID1 and 98.65% used, while the smaller device had only 1 MiB
unallocated. The other device had 107.92 GiB unallocated. New mirrored metadata
needs space on both devices, so the aggregate 132 GiB available in `df` did not
describe the allocation limit. Journald logged ENOSPC and Go crashed while
accessing its telemetry counter.

The host has now recovered. Used space dropped from approximately 567 GiB to
521 GiB, `df` reports 159 GiB available, and metadata utilization is 72.55%.
The Go build cache was cleared from 40 GiB to 8 KiB. Normal Go operation and
durable writes on root and home pass. The smaller device has 3.01 GiB
unallocated; the proposed 8 GiB reserve has not yet been reached.

The proposed PDS feature keeps caches on SSD. An hourly system timer checks
each Btrfs device and alerts below a proposed 8 GiB allocation reserve. A
separate user timer checks the Go build-cache budget every four hours.
Filesystem monitoring never deletes files or starts a balance.

On 2026-11-11 the owner selected this policy, including Go cache exclusion from
future home backups and the resulting cold-cache rebuild trade-off, then
accepted the independently reviewed specification. The owner authorized the
required documentation/claim publication, a verified implementation PR and
installation for user `m` on `fedora-43` after disposable verification. This
grants no merge, release, disk formatting, extra snapshot deletion or automatic
balancing. Implementation and installation have not yet started.

An explicitly authorized manual recovery run may relocate a limited number of data block groups
from the constrained device. It preserves RAID1 metadata and takes before/after
measurements. Recovery is an attempt, not a guarantee: balance can itself fail
with ENOSPC or fail to produce the requested reserve. Both outcomes must be
reported as unresolved. Proposed limits are one block group per invocation and
eight invocations per recovery run, with an early stop when the reserve is met.
These limits bound selected work, not elapsed time or bytes moved. They do not
solve a filesystem that lacks the metadata workspace needed to start balance.

Age-only cleanup was inadequate here. Before cleanup, all 202,526 measured Go
cache objects, totalling 38.45 GiB, were newer than seven days. Home snapshots
included the cache and retained deleted extents. The scheduling proposal requires
separating the disposable Go cache subvolume from home snapshots before enabling
budget-triggered Go cleanup. It does not automatically delete snapshots.

The owner subsequently requested PDS synchronization, repository changes and live
filesystem repair. Upstream PDS was already onboarded at docs revision
`0e52f51f01b84eda75a976763c42d8ec0a07b544`. Its instructions and pin are retained
unchanged after synchronization. The earlier local onboarding additions were
superseded by the existing upstream versions.

The initial bounded empty-data and occupied-data balance attempts failed with
ENOSPC. The remaining metadata space was held almost entirely by Btrfs's global
reserve. Even a verified batch of rebuildable Go objects created after the last
snapshot could not be removed normally. Removing the separately approved local
home snapshots released enough working room for native Go cleanup. Source
files, live browser profiles, module caches and volumes were not selected.

The proposed monitoring and cleanup timers do not exist yet. The owner asked to
clean caches first and prepare the scheduling plan afterward. The owner then
approved removing the November 9 local home snapshot, followed by explicit
approval for the November 10 and 11 copies. Their matching read-only backups
were reverified before deletion. All local root snapshots and live files remain.
Reclamation of the three deleted home snapshots finished. Native Go cleanup
then succeeded, and DNF cleared 110 MiB of disposable cache without removing
packages. All three independent home backups and the local root snapshots
remain. Extra data relocation was cancelled when it affected new SSH sessions;
no balance or other exclusive operation remains active. No disk was added or
formatted. Nothing has been pushed to GitHub.

### Measured evidence

Measurements were taken over SSH on `fedora-43` on 2026-11-11, approximately
10:25 to 10:34 CET. Values describe that observation window.

| Command | Observed result |
| --- | --- |
| `df -hT / /home /tmp` and `findmnt -T /tmp` | Root, home and `/tmp` use the same Btrfs filesystem. `df` reports 699 GiB total, 567 GiB used and 132 GiB available. `/tmp` is not a separate full tmpfs. |
| `sudo btrfs filesystem usage -b /` | Metadata RAID1: 39,711,670,272 bytes allocated, 39,175,995,392 bytes used, approximately 98.65%. |
| `sudo btrfs filesystem show /` | Device 1 is `/dev/sda3`, 221.57 GiB; device 2 is `/dev/nvme0n1p1`, 476.94 GiB. |
| `sudo btrfs filesystem usage -b /` | Device 1 has 1,048,576 bytes unallocated. Device 2 has 115,881,279,488 bytes unallocated. Data is `single`; metadata and system block groups are RAID1. |
| `sudo btrfs device stats /` | All five reported error counters are zero on both devices. These counters do not prove complete device health. |
| `sudo btrfs balance status /` | No balance is running or paused. |
| `sudo btrfs qgroup show /` | Quotas are not enabled. Snapshot-exclusive retained bytes were not measured. |
| `sudo journalctl -k -b --no-pager -g 'BTRFS\|ENOSPC\|No space left'` | Journald failed to open the system journal with ENOSPC at 10:16:01. |
| `go version` | SIGBUS in `cmd/vendor/golang.org/x/telemetry/internal/counter`. A process-local `GOTELEMETRY=off` retry also failed. No telemetry configuration or counter file was changed. |
| Bounded `du -xhd1 "$HOME/.cache"` scan | Approximately 75 GiB of cache: Go build 40 GiB, Playwright 6.6 GiB, Playwright MCP 5.1 GiB, uv 2.9 GiB and Puppeteer 1.3 GiB. |
| `timeout 45 find "$HOME/.cache/go-build" -mindepth 2 -maxdepth 2 -type f -name '*-[ad]' -printf '%T@ %s\n'` with an age/byte aggregation | Exit 0; 202,526 objects, 38.45 GiB logical size, zero objects older than seven or fourteen days. This measures modification time, not live process use. |
| `sudo btrfs subvolume list -o /home` and `findmnt -T "$HOME/.cache"` | No nested home subvolumes were listed; the cache is on the home subvolume. |
| `sudo grep -nE 'snapshot_preserve\|target_preserve\|volume\|subvolume' /etc/btrbk/btrbk.conf` | Root and home are snapshotted. Local retention is `2d` with minimum `latest`; backup retention is `14d 8w 6m`. |
| `sudo btrfs subvolume list -s /` | Six local snapshots: root and home for November 9, 10 and 11. |
| `systemctl show btrbk.service` and `sudo journalctl -u btrbk.service -n 16` | Last recorded run succeeded; November 11 root and home snapshots were sent to `/srv/backup/btrbk`. No restore was tested. |
| `systemctl --user cat clean-caches.service clean-caches.timer` | Neither unit exists. The proposed `~/.local/bin/clean-caches.sh` was also absent. |
| `df -h /srv/bulk /srv/backup` and `lsblk -o NAME,SIZE,ROTA,FSTYPE,MOUNTPOINTS` | Bulk has approximately 930 GiB available on a rotational disk; root devices are non-rotational. Backup has approximately 1.4 TiB available. |

Whole-home and system-directory scans did not finish within the allotted time.
Their partial results do not establish whole-host size rankings. A later
unbounded optional directory scan was stopped. No cleanup or balance ran during
that initial read-only inspection.

The measured allocation layout explains why aggregate free space can coexist
with metadata allocation pressure. Post-repair write tests pass and standard Go
operation no longer crashes. A new interactive Copilot session was not started.

### Authorized recovery observations

- At 10:37 CET the owner requested synchronization and live repair.
- Both `btrfs balance start -dusage=0,devid=1,limit=1 /` and
  `btrfs balance start -ddevid=1,limit=1 /` returned ENOSPC. A subsequent status
  check found no balance running or paused. Metadata remained RAID1.
- Sysfs reported `metadata/bytes_may_use` of 530,939,904 bytes and
  `metadata/bytes_pinned` of 4,390,912 bytes. Metadata used was 39,175,995,392
  bytes of 39,711,670,272 bytes allocated. The global reserve was 536,870,912
  bytes, nearly all reserved.
- GNU `stat` birth times identified 12,526 Go objects totalling 0.81 GiB created
  after 00:01, after the latest home snapshot. No Go build processes were
  observed. The deletion scope requires owned, single-link, regular files at
  depth two with Go's hexadecimal object names.
- GNU `find -newerBt` is unsupported on this host and failed before deleting
  anything. The recovery uses verified GNU `stat` birth times instead.
- The scoped deletion also blocked in `btrfs_reserve_metadata_bytes`. That
  pipeline was cancelled; its final removal count was not available.
- The earlier session's browser-cache removal was separately observed blocked
  in the kernel. It was not terminated by this session.
- A further attempt to reclaim one completely empty metadata block group,
  `btrfs balance start -musage=0,limit=1 /`, also failed with ENOSPC. No balance
  remained active.
- Go works with a temporary RAM-backed `XDG_CONFIG_HOME`:
  `GOTOOLCHAIN=local go version` returned `go1.27.4 linux/amd64`. This avoids the
  failing telemetry counter without changing persistent Go configuration.
  The subsequent bounded `go clean -cache` did not yield a verified successful
  completion and its local SSH command was stopped.
- At 14:39 CET, `df` still reported 567 GiB used and 132 GiB available. Metadata
  utilization was 98.67%; device 1 still had only 1 MiB unallocated.
- A later bounded cache-size check still found 40 GiB in `go-build` and 4.5 GiB
  in `ms-playwright-mcp`. `ms-playwright` no longer existed. Browser-cache
  deletion has not restored usable allocation headroom; retained snapshots
  still reference cache data. No temporary `pds-go-clean.*` directory remained
  in `/dev/shm`.
- The local November 9 home snapshot's UUID was compared with the backup's
  received UUID and matched. Its backup is read-only. At 14:47 CET the owner
  authorized deleting that local copy. Subvolume 271 was removed and the
  deletion committed. A 90-second reclamation wait timed out; the snapshot
  remained queued as `DELETED`.
- The owner subsequently approved removing the November 10 and 11 local home
  snapshots. Both backup received UUIDs matched their sources and both backups
  were read-only. Subvolumes 273 and 275 were removed and the deletion committed.
  The three local root snapshots, IDs 270, 272 and 274, remain.
- After removal of the last two local home snapshots, metadata utilization
  dropped to 96.79% and global reserve consumption reached zero. Snapshot
  reclamation was still pending, so this was working-room recovery, not proof
  of final reclaimed capacity.
- An attempted truncation of one verified post-snapshot Go cache object failed
  with ENOSPC before the last two local home snapshots were removed. Go's
  installed cache implementation checks object size and checksum, but no
  successful truncation was observed.
- Native `go clean -cache` was restarted with the RAM-backed temporary
  configuration, an explicit Go build-cache path and no active Go build tools.
  It returned exit 0 and reduced the cache from 40 GiB to 8 KiB. The temporary
  configuration was removed by its cleanup trap.
- All three deleted home snapshots completed reclamation: `btrfs subvolume
  list -d /` returned no entries.
- One initial bounded data relocation reclaimed only a small legacy block
  group. Chunk-tree inspection then identified exact GiB-sized data groups on
  device 1 for targeted relocation. Extra relocation was stopped when new SSH
  sessions became unresponsive. The active balance was explicitly cancelled
  once control returned; no full balance or profile conversion ran.
- Final `df -h / /home` reported 699 GiB total, 521 GiB used and 159 GiB
  available, compared with the initial 567 GiB used and 132 GiB available.
  These are rounded Btrfs space estimates, not a byte-accurate deletion count.
- Final `btrfs filesystem usage /` reported metadata 26.83 GiB used of
  36.98 GiB, or 72.55%; data remained `single` and metadata/system remained
  RAID1. Device 1 had 3.01 GiB unallocated and device 2 had 107.92 GiB.
  The global reserve was unused. The proposed 8 GiB device reserve was not met.
- `btrfs balance status /` reported no balance; sysfs `exclusive_operation`
  was `none`; all reported device error counters remained zero.
- `go version` with its ordinary persistent configuration returned
  `go1.27.4 linux/amd64` and exit 0. No telemetry configuration or counter file
  was permanently changed.
- `dnf clean all` returned exit 0, removing 67 files and 54 directories totalling
  110 MiB, with zero reported errors. No packages were removed.
- After balance cancellation, independent 64 KiB create/write/fsync/read/delete
  checks passed in `/var/tmp` and `/home/m`. The exact test files were removed.
  Checks also confirmed that all three independent home backups and local root
  snapshots remain, and only the approved local home copies are absent.
- Read-only `wipefs --no-act /dev/sdb` found no signatures on a 223.6 GiB SSD.
  No disk was added, formatted or erased. Missing signatures are not approval
  to use that disk.

### Repository evidence

- [The CLI](../../../packaging/bin/pds) provides explicit command dispatch and a
  configurable library root; see `packaging/bin/pds:7`.
- [Package contents](../../../packaging/nfpm.yaml) already include the common
  Bash tree; see `packaging/nfpm.yaml:45`.
- [Initialization](../../../packaging/init.sh) sources common libraries into
  interactive shells; see `packaging/init.sh:29`. Sourcing a new library must
  not run checks or change shell options.
- [The raw loader](../../../bash/source_all.sh) lists sourced modules explicitly;
  see `bash/source_all.sh:44`.
- [The APT workflow](../../../.github/workflows/build-apt-package.yml) runs
  `packaging/build.sh build` and `make test`; see
  `.github/workflows/build-apt-package.yml:97` and `:101`.

## Scope

Include one Fedora maintenance script, budget-triggered native Go cache cleanup,
read-only Btrfs monitoring, an explicitly authorized Go cache-subvolume preparation,
tests and installation/removal documentation. Keep the existing application
paths and btrbk retention.

Exclude automatic browser installation removal, source/worktree deletion,
persistent Go telemetry changes, relocation onto another disk, `/etc/fstab`
changes, automatic snapshot deletion or retention changes, container/volume pruning, defragmentation,
filesystem resizing and profile conversion. Do not promise that finite storage
can never fill. Monitoring requires an operator to respond to unresolved alerts.

No new PDS CLI command tree, Debian package change, Fedora RPM, publishing path
or release workflow change is included. Fedora uses the script from a checkout;
installation copies it to a stable root-owned local path for the native units.
Keep occupied-group balancing as an explicit maintenance-window operation, not
an automatic scheduler action.

## Design

### Proposed interface and defaults

The installer and commands below are proposed, not installed.

Use `bash/fedora/storage_maintenance.sh` directly from a checkout. Its explicit
modes are `check`, `cleanup-go`, `prepare-go-cache`, `install` and `uninstall`.
Installation names the target user and mount, requires root and separate
authorization, and copies the script to a stable root-owned location. The
cleanup mode runs as the target user, not root. Sourcing the script declares
functions only and preserves caller options and traps.

The script orchestrates existing Btrfs, Go and systemd commands. Do not add a
cache daemon, general storage framework or package publisher.

| Term | Meaning |
| --- | --- |
| Allocatable headroom | Bytes outside allocated block groups on each device, as distinct from `df` available bytes. |
| Reserve | Policy warning threshold of 8 GiB unallocated per participating device, not a Btrfs hard minimum. |
| Bounded recovery | At most eight synchronous data-only balance invocations, each selecting at most one block group, with remeasurement after each. |
| Cache budget | A threshold for native Go cleanup or a browser-cache warning, not an enforced storage quota. |

The proposed monitor warns below the per-device reserve or below 10% aggregate
available space. It also warns above a 20 GiB Go build cache or a combined 15 GiB
of the named Playwright/Puppeteer installation caches. Missing optional caches
are reported as absent; inaccessible caches are errors, never zero-sized.
Metadata utilization is shown with per-device headroom so a high percentage
alone is not misrepresented as proof of ENOSPC.

### Cache cleanup and scheduling proposal

First recover metadata workspace. Do not start migration or install scheduled
cleanup while namespace operations are blocked. Removing cached files cannot
release extents still referenced by home snapshots, and no cron expression
fixes that retention problem.

After recovery and a quiescent migration window, place only the verified Go
build cache in a dedicated nested Btrfs subvolume. Keep its existing application
path and ownership. Do not migrate the whole cache tree: it also contains
working directories and evidence. Verify that btrbk still snapshots only root
and home and does not add the nested Go cache subvolume. Btrfs snapshots are
nonrecursive, so future home snapshots will omit its contents. Existing
snapshots retain their historical cache
extents until their approved retention or separately approved deletion.

Propose a per-user cleanup timer every four hours, offset from the filesystem
check, using `OnCalendar` and `Persistent=true`. Once the Go build cache exceeds
20 GiB, run `go clean -cache` against its explicitly resolved path. Never use
`go clean -modcache`, delete source trees or pass wildcard cache roots. Skip a
busy build window with an explicit warning and retry on the next scheduled run.
This trades cache hits for reclaimed space. The budget triggers cleanup and
does not impose a storage quota.

Browser cleanup needs a verified upstream unused-revision mechanism for each
installed client. Until that is established, audit their 15 GiB combined budget
and report it; do not schedule wholesale Playwright or Puppeteer removal.
Keep profiles, authenticated sessions and currently required browser versions.

An hourly root timer separately checks every participating device's allocation
headroom. Use the selected 8 GiB warning reserve. This setup reports a reserve
breach; it does not restore the reserve or run balancing. The current 3.01 GiB
device-1 reserve will therefore produce a warning until a separately authorized
maintenance window improves it. Cache cleanup alone cannot protect RAID1
metadata allocation.

### Measurement and monitoring

Use `LC_ALL=C` and byte-valued Btrfs measurements, with strict parsing and
explicit errors for missing tools, insufficient permissions or incomplete
output. Do not infer the two devices from Fedora device names. Report other
layouts without attempting repair.

Scheduled reports run hourly through a system service and an
`OnCalendar` timer with `Persistent=true`. Root is needed for complete Btrfs
measurements. The service runs only the check mode, even after reinstallation.
Keep journal output and failed service status for unhealthy or incomplete
checks. Attempt a desktop notification for the configured user when their
session bus is available; record skipped notification delivery or errors in
the journal. No session bus must prevent neither measurement nor its recorded
unhealthy status.

Keep output append-only and plain, with explicit status words and native errors
on stderr. Check returns 0 for healthy, 1 for a measured warning and 2 for
incomplete/error. Cleanup returns 0 after successful native cleanup or an
explicit below-budget skip, 1 when a busy build postpones cleanup and 2 for an
error or refused safety precondition. Do not add a separate presentation layer.

### Manual recovery safety

The manual repair runbook requires explicit authorization, root, a writable Btrfs mount, no missing devices or
reported device errors, no existing exclusive operation, and the supported
two-device `single` data plus RAID1 metadata/system layout. Unknown or partially
converted profiles are refused. Acquire a per-filesystem lock. Refuse an
attempt without usable metadata workspace and report that recovery needs a
separately approved operation. Do not fall back to deleting snapshots or adding
devices.

Choose the constrained device by measured headroom and its discovered device
ID. Inspect chunk sizes rather than assuming one relocation frees a GiB: the
live recovery first selected a tiny legacy group. Bound occupied-group
selection to a verified group and its device range. First attempt one empty
data block group with
`-dusage=0,devid=<id>,limit=1`. If that makes no progress, a subsequent invocation
may use `-ddevid=<id>,limit=1` to move one occupied data block group. Both count
against the eight-invocation budget. Do not repeatedly relocate occupied block
groups after a no-progress result. Stop on errors, exhausted budget or a
remaining unsupported condition. Never run `-m`, `-s`, `convert`, `--force`, a
full balance, or a resize. Never cancel or resume somebody else's operation.

Record before/after headroom, profiles, device counters and every command
outcome. Check all required devices against the reserve before claiming
success. A balance can fail with ENOSPC and can take substantial time despite
the selected-block-group limit.

The live-host runbook first verifies the most recent btrbk outcome and the
absence of an active balance. After separately authorized recovery, compare
headroom and profiles, inspect errors, and perform a small temporary
create/write/fsync/delete check on root and home. Then retry Copilot and Go.
Persistent application failures remain separate findings. Do not delete Go
telemetry state to turn a failed retry into a claimed success.

Run occupied-group relocation only in an explicitly approved maintenance
window. The observed one-GiB limit did not guarantee short runtime or preserve
new SSH-session responsiveness. Keep an existing local control path able to
cancel the owned balance, stop the batch when latency degrades and verify that
no operation remains active. Leave the proposed 8 GiB reserve as unfinished
maintenance when interruption is safer than continuing; never disguise a
partial reserve as a completed one.

Deleting the source-side home snapshots can make the next home backup require
a full send rather than an incremental one. Keep the independent backups and
check the next btrbk outcome and target capacity. Do not silently change its
schedule or retention to hide that recovery consequence.

### Installation and verification

Install a root-owned copy of the script and native units with absolute,
validated paths. Keep a user cleanup timer separate from the root read-only
monitor. Re-running installation preserves the selected user and mount, creates
no duplicate timers and never enables balancing or snapshot deletion. Reject
conflicting unowned files. Validate prerequisites without automatically
installing packages. Uninstallation leaves cache data, backup policy and
unrelated services unchanged.

Use the repository's existing Python test style to execute the real Bash script
with controlled command fixtures. Test native systemd behavior and cache
subvolume migration in a disposable Fedora/Btrfs environment, including busy
builds, unknown files, symlinks, permission failures and cancellation. Do not
run destructive verification against the real host.

## Acceptance Criteria

- [ ] AC-01: After approved Go cache-subvolume preparation, future home snapshots omit Go cache contents while live application paths, ownership, source files and the independent backup schedule and retention remain intact.
- [ ] AC-02: Scheduled filesystem monitoring leaves application/cache contents, allocation profiles and block-group placement unchanged while surfacing a reserve breach despite abundant aggregate free space, with the documented status and notification outcome.
- [ ] AC-03: Unsafe, busy, malformed or unsuccessful cache-preparation and cleanup attempts preserve source/module/profile data and cannot return success when a required check or cleanup fails.
- [ ] AC-04: The installed read-only monitor survives reboot, catches a missed calendar run, remains singular after reinstall, and can be removed without affecting application data or unrelated timers.
- [ ] AC-05: The maintenance script works directly from a Fedora checkout and its installed copy, while ordinary sourcing has no side effects and existing PDS commands retain their behavior.
- [ ] AC-06: Monitoring exposes the documented cache-budget breaches without deleting recent Go objects, installed browsers, profiles or snapshot-retained data, and redirected/plain output retains explicit partial and failure outcomes.
- [ ] AC-07: After an approved cache-subvolume migration, native Go cache cleanup reclaims filesystem space even while new home snapshots are retained, without changing application paths, ownership or live source files.
- [ ] AC-08: The explicitly enabled user cleanup schedule catches missed runs and clears an over-budget Go build cache through the native command while preserving module caches and reporting busy, failed and unsupported cleanup attempts.

## Test Plan

| Criterion | Proof |
| --- | --- |
| AC-01 | Disposable Fedora/Btrfs scenario: prepare the approved cache subvolume, populate it through an actual Go build, snapshot home, and verify cache contents are omitted while source hashes, ownership, application paths and the unchanged backup configuration are preserved. |
| AC-02 | Shell fixtures reproduce the measured Fedora byte output and abundant aggregate free space; command-recording stubs prove no balance/deletion. Assert warning status and journal/desktop outcomes with active, absent and failing session buses. |
| AC-03 | Test absent tools, bad paths, symlinks, permissions, unknown files, active builds, partial output and native cleanup errors. Assert no source/module/profile deletion, no profile changes or balance commands, no silent fallback, and nonzero failed-check status. |
| AC-04 | In a disposable systemd environment, run `systemd-analyze verify`, install twice, inspect `OnCalendar`/`Persistent`, stop/start the timer across a missed event, reboot and observe the next recorded report; uninstall and verify only owned files/timer were removed. |
| AC-05 | Run `bash -n`, focused ShellCheck and Python tests exercising the actual script. Compare options and traps before/after sourcing, exercise check/cleanup from a checkout and its installed copy on disposable Fedora, and verify existing CLI help/info remains unchanged. |
| AC-06 | Fixtures include all-new 38.45 GiB Go objects, browser caches, unavailable caches and snapshots. Assert budgets and absence of destructive check-mode commands. Capture normal and redirected output; verify explicit status, intact paths, no terminal control bytes and documented exit codes. |
| AC-07 | Disposable Btrfs scenario: prepare a cache subvolume under home, create cache data, snapshot home, clean the cache and sync. Verify measurable reclaimed bytes, excluded cache contents in the home snapshot, unchanged application paths/ownership, preserved source hashes and unchanged backup retention. |
| AC-08 | Disposable systemd user scenario with an over-budget cache: inspect calendar/persistence, simulate a missed run, execute native cleanup and verify reclaimed cache space. Assert module/source preservation and explicit busy-build, missing-tool, wrong-subvolume and cleanup-error outcomes. |

## Tasks

None yet; write one-commit tasks after the specification is reviewed and accepted.

## Open Questions

None.

## Review Log

| Date | Review | Kind | Commit | Model | Isolation | Outcome |
| --- | --- | --- | --- | --- | --- | --- |
| 2026-11-11 | R-1 | spec | `64464540e5510f3bc2d66aba09819842a9f7dc56` | unknown | procedural | No findings; model identity not attested |
| 2026-11-11 | R-1 | spec | `64464540e5510f3bc2d66aba09819842a9f7dc56` | n/a | n/a | accepted by owner |

### R-1

NO FINDINGS

## Sources

- [Btrfs balance manual](https://btrfs.readthedocs.io/en/latest/btrfs-balance.html): data/device/usage/limit filters, workspace requirements and ENOSPC limits.
- [Btrfs filesystem manual](https://btrfs.readthedocs.io/en/latest/btrfs-man5.html): defragmentation can break reflinks and increase space usage; it is excluded from recovery.
- [systemd timer manual](https://www.freedesktop.org/software/systemd/man/latest/systemd.timer.html): persistent catch-up applies to `OnCalendar` timers, not an interval-only timer.
- [Btrfs subvolumes](https://btrfs.readthedocs.io/en/latest/Subvolumes.html): nested subvolumes are excluded from nonrecursive parent snapshots; received UUIDs identify source snapshots.
- [Feature documents](https://github.com/vhco-pro/docs/blob/0e52f51f01b84eda75a976763c42d8ec0a07b544/conventions/feature-documents.md): draft, review, acceptance and evidence requirements at the existing PDS pin.
