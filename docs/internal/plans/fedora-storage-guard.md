---
status: draft
status_description: "Cleanup blocked by metadata exhaustion; specific snapshot/disk recovery permission is missing. Scheduling remains a draft."
issue: null
goal: "Restore allocatable Btrfs metadata headroom through bounded maintenance and detect its exhaustion before applications fail."
covers:
  - bash/common/admin/storage_guard.sh
  - bash/source_all.sh
  - packaging/bin/pds
  - tests/storage_guard_test.sh
  - tests/storage_guard_integration.sh
  - docs/fedora-storage-guard.md
  - bash/readme.md
  - readme.md
  - changelog.md
---

# Plan: Fedora storage guard

Provide a repeatable PDS storage check and an explicit, bounded recovery command.
Keep the default scheduled operation read-only.

## Context

### Owner summary

Fedora's root and home share a two-device Btrfs filesystem. Metadata is RAID1,
but the smaller device has only 1 MiB of unallocated space. The other device has
107.92 GiB unallocated. New mirrored metadata needs space on both devices, so
the aggregate 132 GiB available in `df` does not describe the allocation limit.
Journald logged ENOSPC during this boot, and Go also crashes in its telemetry
counter code. The exact Go failure has not been proved to share this cause.

The proposed PDS feature keeps caches on SSD. A system timer checks each Btrfs
device every four hours and alerts when allocation headroom falls below a
proposed 8 GiB reserve. It also checks aggregate available space and cache
sizes. Monitoring never deletes files or starts a balance.

An explicit recovery command may relocate a limited number of data block groups
from the constrained device. It preserves RAID1 metadata and takes before/after
measurements. Recovery is an attempt, not a guarantee: balance can itself fail
with ENOSPC or fail to produce the requested reserve. Both outcomes must be
reported as unresolved. Proposed limits are one block group per invocation and
eight invocations per recovery run, with an early stop when the reserve is met.
These limits bound selected work, not elapsed time or bytes moved. They do not
solve a filesystem that lacks the metadata workspace needed to start balance.

Age-only cleanup is inadequate here. All 202,526 measured Go cache objects,
totalling 38.45 GiB, are newer than seven days. Home snapshots also include the
cache and retain deleted extents. The scheduling proposal therefore requires
separating disposable cache subvolumes from home snapshots before enabling
budget-triggered Go cleanup. It does not automatically delete snapshots.

The owner subsequently requested PDS synchronization, repository changes and live
filesystem repair. Upstream PDS was already onboarded at docs revision
`0e52f51f01b84eda75a976763c42d8ec0a07b544`. Its instructions and pin are retained
unchanged after synchronization. The earlier local onboarding additions were
superseded by the existing upstream versions.

The bounded empty-data and occupied-data balance attempts both failed with
ENOSPC. The remaining metadata space is held almost entirely by Btrfs's global
reserve. Recovery is now removing only a verified batch of rebuildable Go cache
objects created after the latest home snapshot, before retrying allocation
maintenance. This emergency action is not an automatic deletion policy. No
browser, profile, source tree, snapshot or volume is selected.

The proposed monitoring and cleanup timers do not exist yet. The owner asked to
clean caches first and prepare the scheduling plan afterward. Cleanup has not
restored allocation headroom. Removing a local snapshot or using another disk
requires a specific decision; neither has been authorized. Nothing has been
pushed to GitHub.

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
unbounded optional directory scan was stopped. No cleanup or balance ran.

The measured allocation layout explains why aggregate free space can coexist
with metadata allocation pressure. No post-repair write test has yet confirmed
that relieving this pressure resolves the reported Copilot failure.

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
  received UUID and matched. Its backup is read-only. Specific approval to
  delete that local copy was requested but not received.
- Read-only `wipefs --no-act /dev/sdb` found no signatures on a 223.6 GiB SSD.
  No disk was added, formatted or erased. Missing signatures are not approval
  to use that disk.

### Repository evidence

- [The CLI](../../../packaging/bin/pds) provides explicit command dispatch and a
  configurable library root; see `packaging/bin/pds:7`.
- [Package contents](../../../packaging/nfpm.yaml) already include the common
  Bash tree; see `packaging/nfpm.yaml:54`.
- [Initialization](../../../packaging/init.sh) sources common libraries into
  interactive shells; see `packaging/init.sh:27`. Sourcing a new library must
  not run checks or change shell options.
- [The raw loader](../../../bash/source_all.sh) lists sourced modules explicitly;
  see `bash/source_all.sh:48`.
- [The APT workflow](../../../.github/workflows/build-apt-package.yml) runs
  `packaging/build.sh build` and `make test`; see
  `.github/workflows/build-apt-package.yml:90`.

## Scope

Include a sourceable Bash library that also runs directly from a checkout,
PDS CLI dispatch, scheduled monitoring, an opt-in bounded Btrfs repair,
budget-triggered native Go cache cleanup, a separately approved cache-subvolume
migration, tests and installation/removal documentation.

Exclude automatic browser installation removal, source/worktree deletion,
persistent Go telemetry changes, relocation onto another disk, `/etc/fstab`
changes, automatic snapshot deletion or retention changes, container/volume pruning, defragmentation,
filesystem resizing and profile conversion. Do not promise that finite storage
can never fill. Monitoring requires an operator to respond to unresolved alerts.

No Fedora RPM, new publishing path or release workflow change is included.
The Debian package still carries the common library; Fedora uses the checkout's
standalone script.

## Design

### Proposed interface and defaults

All interfaces below are proposed, not installed.

- `pds storage report --mount / --user m`: read-only measurements and status.
- `pds storage repair --mount / --apply`: bounded data-only recovery.
- `pds storage cleanup --user m --apply`: native Go build-cache cleanup after
  verifying that its dedicated cache subvolume is excluded from home snapshots.
- `pds storage install --mount / --user m`: install the monitor and enable its
  system timer, requiring root and separate deployment authorization.
- `pds storage uninstall`: disable and remove only PDS-owned monitor files.
- The same modes are available through
  `bash bash/common/admin/storage_guard.sh <mode> ...` without a package.

| Term | Meaning |
| --- | --- |
| Allocatable headroom | Bytes outside allocated block groups on each device, as distinct from `df` available bytes. |
| Reserve | Proposed minimum of 8 GiB unallocated on every device required by the supported two-device RAID1 metadata layout. |
| Bounded recovery | At most eight synchronous data-only balance invocations, each selecting at most one block group, with remeasurement after each. |
| Cache budget | An alert threshold, not a deletion target or enforced storage quota. |

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
build cache and browser-installation caches in dedicated nested Btrfs
subvolumes. Keep their existing application paths and ownership. Do not migrate
the whole cache tree: it also contains working directories and evidence.
Verify that btrbk still snapshots only root and home and does not add these
nested subvolumes. Btrfs snapshots are nonrecursive, so future home snapshots
will omit their contents. Existing snapshots retain their historical cache
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

The root timer separately checks every participating device's allocation
headroom. Keep the 8 GiB reserve and bounded repair design below. Whether it may
run that repair automatically before the reserve is exhausted is an explicit
owner choice. Cache cleanup alone cannot protect RAID1 metadata allocation.

### Measurement and monitoring

Use `LC_ALL=C` and byte-valued Btrfs measurements, with strict parsing and
explicit errors for missing tools, insufficient permissions or incomplete
output. Do not infer the two devices from Fedora device names. Report other
layouts without attempting repair.

Scheduled reports run every four hours through a system service and an
`OnCalendar` timer with `Persistent=true`. Root is needed for complete Btrfs
measurements. The service runs only the report mode, even after reinstallation.
Keep journal output and failed service status for unhealthy or incomplete
checks. Attempt a desktop notification for the configured user when their
session bus is available; record skipped notification delivery or errors in
the journal. No session bus must prevent neither measurement nor its recorded
unhealthy status.

Keep logs append-only and plain when redirected. Follow the pinned terminal
output convention for labelled status and the explicit `--plain` mode. Report
returns 0 for healthy, 1 for a measured warning and 2 for incomplete/error;
repair returns 0 only when remeasurement meets the reserve, 1 for a completed
attempt with insufficient headroom and 2 for an error/refused precondition.

### Recovery safety

Repair requires `--apply`, root, a writable Btrfs mount, no missing devices or
reported device errors, no existing exclusive operation, and the supported
two-device `single` data plus RAID1 metadata/system layout. Unknown or partially
converted profiles are refused. Acquire a per-filesystem lock. Refuse an
attempt without usable metadata workspace and report that recovery needs a
separately approved operation. Do not fall back to deleting snapshots or adding
devices.

Choose the constrained device by measured headroom and its discovered device
ID. First attempt one empty data block group with
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

### Installation and delivery

Install a root-owned copy of the script and systemd units with absolute,
validated paths. Re-running installation must preserve its selected mount and
user without creating duplicate timers or enabling repair. Reject conflicting
unowned files. Installation validates prerequisites without automatically
installing packages. Uninstallation leaves application data and unrelated
services unchanged.

The implementation adds the library to the raw loader and the existing CLI.
The current nFPM common-tree inclusion carries it into the `.deb`. Validate
that artifact through the workflow's build/test commands and inspect its
contents. Test standalone execution on Fedora separately. Do not run mutation
tests against the real host or start a release workflow during development.

## Acceptance Criteria

- [ ] AC-01: On an isolated supported Btrfs filesystem with one constrained device and spare space on its peer, authorized bounded recovery restores the configured per-device reserve, preserves metadata redundancy and existing files, and allows a previously failing create/write/fsync operation to succeed.
- [ ] AC-02: Scheduled operation leaves files, allocation profiles and block-group placement unchanged while surfacing a reserve breach despite abundant aggregate free space, with the documented status and notification outcome.
- [ ] AC-03: Unsafe, concurrent, malformed or unsuccessful recovery attempts cannot exceed the documented work limit, change profiles, delete files or return success while any required reserve remains unmet.
- [ ] AC-04: The installed read-only monitor survives reboot, catches a missed calendar run, remains singular after reinstall, and can be removed without affecting application data or unrelated timers.
- [ ] AC-05: The same storage commands work from a Fedora checkout and the built PDS Debian package, while ordinary sourcing has no side effects and existing CLI commands retain their behavior.
- [ ] AC-06: Monitoring exposes the documented cache-budget breaches without deleting recent Go objects, installed browsers, profiles or snapshot-retained data, and redirected/plain output retains explicit partial and failure outcomes.
- [ ] AC-07: After an approved cache-subvolume migration, native Go cache cleanup reclaims filesystem space even while new home snapshots are retained, without changing application paths, ownership or live source files.
- [ ] AC-08: The explicitly enabled user cleanup schedule catches missed runs and clears an over-budget Go build cache through the native command while preserving module caches and reporting busy, failed and unsupported cleanup attempts.

## Test Plan

| Criterion | Proof |
| --- | --- |
| AC-01 | Disposable two-device loopback Btrfs scenario, with a reduced configurable test reserve: establish allocation pressure and a failed write, retain file hashes, run bounded repair, verify reserve on both devices, unchanged RAID1 metadata and hashes, then observe successful write/fsync. If that scenario cannot establish a failing baseline, record the missing proof and do not claim this criterion met. |
| AC-02 | Shell fixtures reproduce the measured Fedora byte output and abundant aggregate free space; command-recording stubs prove no balance/deletion. Assert warning status and journal/desktop outcomes with active, absent and failing session buses. |
| AC-03 | Test absent tools, bad arguments, permissions, missing devices, error counters, unsupported/mixed profiles, active/paused balance, lock conflict, partial output, ENOSPC, no progress and budget exhaustion. Assert selected device, maximum invocation count, exact data-only filters and nonzero unresolved status. |
| AC-04 | In a disposable systemd environment, run `systemd-analyze verify`, install twice, inspect `OnCalendar`/`Persistent`, stop/start the timer across a missed event, reboot and observe the next recorded report; uninstall and verify only owned files/timer were removed. |
| AC-05 | Run `bash -n`, focused ShellCheck and shell tests. Source the library and compare options, traps and variables. Exercise CLI help/report and existing help/info with a checkout library root. Run the APT workflow's `packaging/build.sh build` and `make test`, inspect/extract the `.deb` and exercise its CLI. Separately execute standalone report on Fedora with read-only authority. |
| AC-06 | Fixtures include all-new 38.45 GiB Go objects, browser caches, unavailable caches and snapshots. Assert budgets and absence of destructive commands. Capture Unicode/plain and redirected output with `NO_COLOR` absent, empty, `0` and nonempty; verify status words, no terminal control in plain output, and documented exit codes. |
| AC-07 | Disposable Btrfs scenario: prepare a cache subvolume under home, create cache data, snapshot home, clean the cache and sync. Verify measurable reclaimed bytes, excluded cache contents in the home snapshot, unchanged application paths/ownership, preserved source hashes and unchanged backup retention. |
| AC-08 | Disposable systemd user scenario with an over-budget cache: inspect calendar/persistence, simulate a missed run, execute native cleanup and verify reclaimed cache space. Assert module/source preservation and explicit busy-build, missing-tool, wrong-subvolume and cleanup-error outcomes. |

## Tasks

None yet; write one-commit tasks after the specification is reviewed and accepted.

## Open Questions

### Q1: Should the default policy keep caches on SSD and schedule read-only monitoring?

**Recommendation:** A. Keep the existing cache locations and require an explicit
bounded recovery command. This addresses the measured allocation problem
without deleting installed tooling or changing active paths.

| Option | You get | It costs |
| --- | --- | --- |
| **A. Read-only filesystem monitor and explicit repair** | Proposed four-hour monitoring, 8 GiB per-device reserve, 10% aggregate warning, separately enabled native Go cleanup after snapshot exclusion, and at most eight one-block-group repair invocations | Filesystem alerts require an operator response; thresholds and migration need acceptance |
| **B. Automatic bounded balancing** | Allocation maintenance can run without an operator | Recurring root-filesystem writes and I/O; requires a revised scope and safety/operation policy |
| **C. Selected caches on bulk storage** | Cache growth consumes less root capacity | Slower rotational storage, mount dependency and a separately planned migration |

**Why this is yours:** These choices determine whether the host makes unattended
filesystem changes or trades build performance for capacity. No answer was
received in this session; option A is a proposal, not acceptance.

### Q2: May the backed-up November 9 local home snapshot be removed to attempt recovery?

**Recommendation:** A. Preserve the verified backup and attempt removal of only
the local copy before another bounded cleanup attempt.

| Option | You get | It costs |
| --- | --- | --- |
| **A. Remove that one local copy** | A possible way to free metadata needed for cache deletion; the matching backup and newer local snapshots remain | One local rollback point is removed; recovery can still fail or need a further decision |
| **B. Preserve every snapshot** | All local rollback points remain | Cleanup stays blocked unless another approved recovery method provides workspace |

**Why this is yours:** Live filesystem repair and cache cleanup do not authorize
deleting snapshot history. No specific approval was received. Adding the
apparently unused SSD is also withheld unless that exact disk is authorized.

## Review Log

| Date | Review | Kind | Commit | Model | Isolation | Outcome |
| --- | --- | --- | --- | --- | --- | --- |

## Sources

- [Btrfs balance manual](https://btrfs.readthedocs.io/en/latest/btrfs-balance.html): data/device/usage/limit filters, workspace requirements and ENOSPC limits.
- [Btrfs filesystem manual](https://btrfs.readthedocs.io/en/latest/btrfs-man5.html): defragmentation can break reflinks and increase space usage; it is excluded from recovery.
- [systemd timer manual](https://www.freedesktop.org/software/systemd/man/latest/systemd.timer.html): persistent catch-up applies to `OnCalendar` timers, not an interval-only timer.
- [Btrfs subvolumes](https://btrfs.readthedocs.io/en/latest/Subvolumes.html): nested subvolumes are excluded from nonrecursive parent snapshots; received UUIDs identify source snapshots.
- [Feature documents](https://github.com/vhco-pro/docs/blob/0e52f51f01b84eda75a976763c42d8ec0a07b544/conventions/feature-documents.md): draft, review, acceptance and evidence requirements at the existing PDS pin.
