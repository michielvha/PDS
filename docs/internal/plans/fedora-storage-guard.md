---
status: draft
status_description: "Diagnosis measured; policy, live recovery and implementation await owner approval."
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
These limits bound selected work, not elapsed time or bytes moved.

Age-only cleanup is inadequate here. All 202,526 measured Go cache objects,
totalling 38.45 GiB, are newer than seven days. Home snapshots also include the
cache and may retain deleted extents. Automatic cache deletion and changing
snapshot policy are excluded from this feature.

Only read-only host measurements have run. The script, timer, repair path and
their tests do not exist yet. The policy choices below remain unanswered because
the owner was unavailable. Accepting a reviewed specification would authorize
its scoped implementation; pushing, installing on Fedora and repairing the live
filesystem require their own authorization.

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
PDS CLI dispatch, scheduled read-only monitoring, an opt-in bounded Btrfs repair,
tests and installation/removal documentation.

Exclude automatic cache deletion, browser installation removal, source/worktree
deletion, Go telemetry repair, cache migration, `/etc/fstab` changes, snapshot
deletion or retention changes, container/volume pruning, defragmentation,
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
converted profiles are refused. Acquire a per-filesystem lock.

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

## Test Plan

| Criterion | Proof |
| --- | --- |
| AC-01 | Disposable two-device loopback Btrfs scenario, with a reduced configurable test reserve: establish allocation pressure and a failed write, retain file hashes, run bounded repair, verify reserve on both devices, unchanged RAID1 metadata and hashes, then observe successful write/fsync. If that scenario cannot establish a failing baseline, record the missing proof and do not claim this criterion met. |
| AC-02 | Shell fixtures reproduce the measured Fedora byte output and abundant aggregate free space; command-recording stubs prove no balance/deletion. Assert warning status and journal/desktop outcomes with active, absent and failing session buses. |
| AC-03 | Test absent tools, bad arguments, permissions, missing devices, error counters, unsupported/mixed profiles, active/paused balance, lock conflict, partial output, ENOSPC, no progress and budget exhaustion. Assert selected device, maximum invocation count, exact data-only filters and nonzero unresolved status. |
| AC-04 | In a disposable systemd environment, run `systemd-analyze verify`, install twice, inspect `OnCalendar`/`Persistent`, stop/start the timer across a missed event, reboot and observe the next recorded report; uninstall and verify only owned files/timer were removed. |
| AC-05 | Run `bash -n`, focused ShellCheck and shell tests. Source the library and compare options, traps and variables. Exercise CLI help/report and existing help/info with a checkout library root. Run the APT workflow's `packaging/build.sh build` and `make test`, inspect/extract the `.deb` and exercise its CLI. Separately execute standalone report on Fedora with read-only authority. |
| AC-06 | Fixtures include all-new 38.45 GiB Go objects, browser caches, unavailable caches and snapshots. Assert budgets and absence of destructive commands. Capture Unicode/plain and redirected output with `NO_COLOR` absent, empty, `0` and nonempty; verify status words, no terminal control in plain output, and documented exit codes. |

## Tasks

None yet; write one-commit tasks after the specification is reviewed and accepted.

## Open Questions

### Q1: Should the default policy keep caches on SSD and schedule read-only monitoring?

**Recommendation:** A. Keep the existing cache locations and require an explicit
bounded recovery command. This addresses the measured allocation problem
without deleting installed tooling or changing active paths.

| Option | You get | It costs |
| --- | --- | --- |
| **A. Read-only monitor and explicit repair** | Proposed four-hour monitoring, 8 GiB per-device reserve, 10% aggregate warning, 20 GiB Go and 15 GiB browser budgets, and at most eight one-block-group repair invocations | Alerts require an operator response; thresholds need acceptance |
| **B. Automatic bounded balancing** | Allocation maintenance can run without an operator | Recurring root-filesystem writes and I/O; requires a revised scope and safety/operation policy |
| **C. Selected caches on bulk storage** | Cache growth consumes less root capacity | Slower rotational storage, mount dependency and a separately planned migration |

**Why this is yours:** These choices determine whether the host makes unattended
filesystem changes or trades build performance for capacity. No answer was
received in this session; option A is a proposal, not acceptance.

### Q2: May the current Fedora host receive bounded live recovery and a monitor installation?

**Recommendation:** A. Keep this work local until the owner approves the exact
live operation and reviews the tested implementation.

| Option | You get | It costs |
| --- | --- | --- |
| **A. Prepare only** | Persistent diagnosis and a reviewable specification | The current host remains under allocation pressure |
| **B. Approve bounded recovery after verification** | A tested recovery attempt and measured write checks | Filesystem I/O on the live host; independent approval is still needed for timer installation |

**Why this is yours:** Implementation acceptance does not grant live-operation
or deployment permission. The owner was unavailable when asked.

## Review Log

| Date | Review | Kind | Commit | Model | Isolation | Outcome |
| --- | --- | --- | --- | --- | --- | --- |

## Sources

- [Btrfs balance manual](https://btrfs.readthedocs.io/en/latest/btrfs-balance.html): data/device/usage/limit filters, workspace requirements and ENOSPC limits.
- [Btrfs filesystem manual](https://btrfs.readthedocs.io/en/latest/btrfs-man5.html): defragmentation can break reflinks and increase space usage; it is excluded from recovery.
- [systemd timer manual](https://www.freedesktop.org/software/systemd/man/latest/systemd.timer.html): persistent catch-up applies to `OnCalendar` timers, not an interval-only timer.
- [Feature documents](https://github.com/vhco-pro/docs/blob/d8f07c9dd69038375a535af8ad586086688f85ab/conventions/feature-documents.md): draft, review, acceptance and evidence requirements.
- [Terminal output](https://github.com/vhco-pro/docs/blob/d8f07c9dd69038375a535af8ad586086688f85ab/conventions/terminal-output.md): explicit status, plain output and stream behavior.
