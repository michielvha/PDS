---
status: in-progress
status_description: "Implementing the R-5 accepted broader retention/audit policy on the existing owning branch."
branch: feat/fedora-storage-guard
issue: null
goal: "Keep disposable build/package/container caches bounded and surface persistent developer-storage growth without deleting project or volume data."
covers:
  - bash/fedora/storage_maintenance.sh
  - bash/fedora/storage_consumers.sh
  - tests/test_storage_maintenance.py
  - tests/test_storage_consumers.py
  - docs/fedora-storage-guard.md
  - bash/readme.md
  - changelog.md
---

# Plan: Fedora storage guard

Make native Go cache cleanup repeatable and exclude rebuildable Go cache from
future home snapshots. Cover the larger container/package-cache consumers
through native retention and explicit read-only reports for persistent data.

## Context

### Owner summary

The owner expanded this feature after identifying much larger Docker/Podman
build caches, images, volumes, builders directories, review archives and
worktrees. On November 12, they selected native cache/image cleanup with
seven-day unused-image retention, plus audit-only handling for volumes,
worktrees, review directories, Go modules and editor data. The original
Go-only code passed independent R-3; that review does not verify the new scope.

The revised design retains four-hour Go checks and hourly Btrfs monitoring.
It adds daily host-local Docker build-cache pruning to a 20 GB target with a
10 GB reserve, and daily native pruning of unreferenced images created more
than seven days ago. Referenced images, containers and volumes remain. Images
previously used for rollback or local builds may need downloading or rebuilding.
Npm verification and eligibility-guarded non-forced uv pruning run as the user; no whole-cache
wildcard deletion is introduced. These are native retention targets, not
hard quotas, and active/required content may keep usage above target.

Daily reports cover all named directory/storage classes, including orphan-volume
counts, builders directories, registered/locked worktrees, review archives,
Go modules, npm, Zed and the remaining user cache. Permission errors and scan
timeouts remain explicit incomplete results. A directory name, old timestamp,
unreferenced volume or clean Git worktree never authorizes deletion. Review
archives and worktrees may contain unpushed code, evidence or databases.

The extension uses one companion Bash script alongside the existing helper,
native system/user timers and existing jq for structured container accounting.
No daemon restart, Docker configuration replacement or global container prune
is needed. Runtime endpoint selection is confined to this host, not inherited
remote Docker/Podman contexts. Rollback removes only managed jobs/scripts;
already discarded caches/images regenerate on demand.

No broader cleanup has run. The revised tests must prove command allowlists,
seven-day filters, no volume/container/worktree deletion, endpoint confinement,
failure reporting and preservation in native disposable container engines.
Acceptance of the reviewed revision authorizes scoped implementation; installing
the additional jobs and applying retention needs renewed explicit live approval.

### Original incident and verified recovery

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
balancing. Implementation has passed the focused tests and disposable Fedora verification.
Live installation remains pending independent implementation review.

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

The live host's monitoring and cleanup timers are not installed yet. The owner asked to
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

### Implementation verification

The script, guide and tests are implemented on `feat/fedora-storage-guard`.
The focused suite includes a real Fedora/systemd container
with owned two-device Btrfs loopback storage. It verifies cache exclusion and
physical reclamation, interrupted preparation, UID/GID/mode preservation,
fresh-cache initialization, native units, restrictive-umask installation,
literal executable paths, conflicting-file refusal, reinstallation, reboot
catch-up, safe uninstall and unchanged existing PDS CLI output.

The native run uses a local Docker Desktop kernel, not the live Fedora kernel
or its enforcing SELinux policy. Target-host installation and service checks
remain separate authorized steps. The latest read-only target preflight found
the expected `/home/m/.cache/go-build`, stable Homebrew Go executable, no active
Go build tools, an active user bus and enforcing SELinux.

R-2 found that the 19-check baseline did not constrain inherited Go flags.
Native probes reproduced module deletion with persistent `GOFLAGS=-modcache`.
T3 adds ambient/persisted-flag regressions and disables Go's persistent env
configuration only for native cleanup children. Preparation's configuration
query still reads the existing cache path. Module markers and the user's Go
settings file now survive direct preparation, direct cleanup and installed
service execution in disposable Fedora. The blocking review remains history
until an independent re-review verifies the new commit.

The repaired source target is `3f1aa2fd7bb3a16118f5eb5f366bd691cdf9e58c`.
The original synchronous reviewer could not accept a follow-up. A fresh bounded
independent re-review dispatch failed before returning a result because its
model HTTP connection closed after five native retries. No review row or model
identity is fabricated for that failure. No live preparation, timer
installation, feature-branch push or implementation PR has run. The accepted
publication and live-operation permissions remain scoped to verified delivery.

Python test execution validates parsing and runtime behavior. The initial
Pylance syntax check passed; a later editor syntax-check request timed out.
No editor type-check result is claimed.

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

### Additional consumer measurements

Read-only checks on 2026-11-12 distinguished current usage from the owner's
earlier inventory. Do not treat already-cleared caches as currently occupied.

| Command | Current observation |
| --- | --- |
| `docker system df` | Images 46.95 GB, 25.44 GB reclaimable; volumes 47.57 GB, 34.96 GB reclaimable; 118 total volumes, 9 attached; build cache currently 0 bytes. The earlier 121 GB build-cache inventory describes the growth case to prevent. |
| `docker volume ls -q --filter dangling=true` | 109 volumes not referenced by any container. Their data value was not established. |
| `docker buildx ls` | One default builder using the host Docker driver; no custom daemon GC configuration was found. |
| `podman system df --format json` | Current rootless images 1.68 GB with 1.27 GB reported reclaimable; two stopped containers remain. Earlier 61 GB inventory is not the current image size. |
| Bounded `du` under `/home/m/code/.cache` | Total 4.8 GiB; seven `builders-*` directories remain, far below the earlier 75 GB inventory. Other assessment directories remain and are not assumed disposable. |
| `du` and `git -C /home/m/code/stackweaver worktree list --porcelain` | Claude worktrees 21 GiB and several registered worktrees locked. The main worktree and registered branches are not cleanup targets. |
| Bounded `du` under `/home/m/code` | Review archive 12 GiB; security directory at least 5.6 GiB and maintenance directory at least 12 GiB with permission errors. Partial readings are incomplete, not authoritative totals. |
| Bounded `du` under `/home/m/.npm` | Npm cache total 9.8 GiB: content cache 7.7 GiB and npx 2.2 GiB. |
| Bounded cache/module scans | User-cache and Go-module traversals timed out. Some observed components include Go build 757 MiB, uv 2.9 GiB and Playwright MCP 4.5 GiB. Whole-tree totals are unknown. |
| Native help and structured output | Docker supports `buildx prune --max-used-space --reserved-space`; image prune supports `until`; Podman supports local image prune; npm supports cache verify; uv supports non-forced cache prune. Docker emits JSON records and Podman a JSON array, with raw Podman byte fields. |

## Scope

Include one Fedora maintenance script, budget-triggered native Go cache cleanup,
read-only Btrfs monitoring, an explicitly authorized Go cache-subvolume preparation,
one companion for container/package retention and developer-storage auditing,
tests and installation/removal documentation. Keep the existing application
paths and btrbk retention.

Exclude automatic browser installation removal, source/worktree deletion,
persistent Go telemetry changes, relocation onto another disk, `/etc/fstab`
changes, automatic snapshot deletion or retention changes, container/volume pruning, defragmentation,
filesystem resizing and profile conversion. Do not promise that finite storage
can never fill. Monitoring requires an operator to respond to unresolved alerts.

Exclude automatic removal of Docker/Podman containers or volumes, Git worktrees,
builders/review/maintenance/security directories, Go modules and Zed data. Native
image pruning is restricted to local engines and seven-day-old unreferenced
images. Never use `system prune`, `volume prune`, container deletion, Podman's
external-image removal or a forced uv prune.

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

### Additional consumer policy

Use `bash/fedora/storage_consumers.sh` with explicit `audit-docker`,
`cleanup-docker`, `audit-user` and `cleanup-user` operations. Sourcing has no
effects. The existing installer copies the companion to a root-owned stable
location and installs one daily root job at 04:45 and one daily user job at
05:15. Both timers use `OnCalendar` and `Persistent=true`. Their services keep
audit-before/after output and native cleanup outcomes in the journal. Errors
from one category do not conceal measurements of the remaining categories;
the final result must still report incomplete/failed work.

The root job uses only `unix:///var/run/docker.sock` and builder `default`,
ignoring ambient remote endpoints/contexts and builder selection. It invokes
`docker buildx prune --builder default --max-used-space 20000000000 --reserved-space 10000000000 --force`
and `docker image prune --all --filter until=168h --force`. The space settings
are explicit bytes for decimal 20 GB and 10 GB; no suffix-dependent parsing is
assumed. In-use records are preserved by the
engine. Any excess that cannot be reclaimed remains visible in the report.
No Docker daemon configuration is changed or restarted.

The user job uses only local rootless Podman and invokes
`podman --remote=false image prune --all --filter until=168h --force`,
`npm cache verify` with an explicit validated account-local cache and
`uv --no-config --offline cache prune` with an explicit validated cache path only
after the eligibility checks below pass.
Do not pass uv `--force` or `--ci`. Missing optional tools are reported as
skipped, while installed but inaccessible engines/caches are errors. Native
npm verification is not a promise to clear all npx or content bytes; any
remaining over-budget cache still warns.

The owner selected an eligibility guard for uv because native pruning can
delete cached environments still linked by projects. Only source-reviewed and
native-tested uv versions are eligible; initially whitelist exactly 0.10.9.
Upgrades do not silently inherit approval. Resolve the default account-local
cache, reject path aliases/symlinks and unknown top-level cache buckets, and
refuse pruning if any `environments-*` bucket exists, even if it looks old or
empty. An active uv process or an unreadable eligibility check also prevents
pruning. Preserve and report the skip reason. Current host uv 0.10.9 has an
`environments-v2` bucket, so its expected outcome is audit-only. Do not remove
that bucket to make the guard pass. The native in-use check remains enabled;
never use `--force`. Fixtures and a native linked-project-environment regression
must prove the refusal preserves its marker and does not invoke prune.

`until=168h` is an image-creation cutoff as enforced by the engines, not proof
that an image has gone unused for seven days. Images referenced by even stopped
containers remain protected. Persistent volumes are never automatically pruned.

Read-only reports print native structured Docker/Podman accounting, orphan
volume count and bounded directory sizes. Thresholds are warning policies:
Docker build cache over 30 GB, container images over 40 GB per engine, volumes
over 30 GB or more than 50 unattached Docker volumes; builders directories
over 20 GiB; worktrees/review directories over 10 GiB per class; Go modules
over 20 GiB; npm over 5 GiB; Zed over 5 GiB; total user cache over 50 GiB.
Directory readings may overlap and must never be summed as exclusive usage.

Discover `builders-*`, `.triage-review-archive`, `stackweaver-maintenance-*`,
`stackweaver-security-full-cycle.*` and registered Claude worktrees only
under the selected user's canonical code root. Default to `$HOME/code`, with
no recursive removal or interpretation of directory names as shell commands.
Report Git locks and registration from native read-only worktree inventory.
Report unknown Zed locations explicitly; do not confuse editor settings with
disposable cache. Scan each selected directory with a time limit and surface
permission errors and timeouts with its path. Apply no age-based file deletion.

The expanded installer preflights optional tool capabilities, owned file
conflicts and the companion before enabling the additional timers. Reinstall
and removal include exactly the additional managed units/program, preserving
unrelated services and the existing user/daemon configurations. Install does
not itself run the new pruning modes.

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
- [ ] AC-09: Scheduled native Docker retention reclaims eligible local build cache and unreferenced images older than seven days while preserving referenced images, all containers, volume contents and remote engines.
- [ ] AC-10: Scheduled local rootless Podman, npm and uv maintenance uses only the approved native operations, preserves referenced images and project/environment data, and reports skipped, failed or still-over-budget outcomes.
- [ ] AC-11: Daily reports identify Docker/Podman image and volume usage, unattached Docker volumes, builders directories, review archives, registered/locked worktrees, Go modules, npm, Zed and the remaining user cache without deleting any audit-only content or hiding partial scans.
- [ ] AC-12: The additional managed timers preserve their exact cadence and retention after reboot/reinstall, can be removed without disturbing unrelated jobs or data, and never broaden cleanup through inherited endpoints or configuration.

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
| AC-09 | Fixtures assert exact BuildKit space options, 168h image cutoff, fixed host socket/default builder and forbidden command absence. A disposable Docker daemon contains an active/referenced image, unused candidate, stopped container and unattached volume marker; native pruning preserves protected content while reclaiming eligible cache/image records. |
| AC-10 | Command fixtures assert rootless/local Podman, native npm verify, non-forced offline uv prune only for the eligible version/layout, validated paths and visible missing-tool/failure outcomes. Disposable native Podman/npm/uv scenarios verify generated package/image caches, referenced-image and project/environment marker preservation. A project symlink into an environments bucket, an unknown version/bucket and active uv each prevent prune; their markers remain. |
| AC-11 | Fixtures reproduce the supplied growth classes and incomplete readings, including directory names with shell metacharacters, locked/dirty/unmerged worktrees, orphan volumes, unknown editor cache, permission errors and timeout. Assert explicit class/path/threshold warnings and no destructive commands or filesystem changes in audit modes. |
| AC-12 | Disposable systemd/container runtime: install twice, inspect exact daily/root/user calendars plus Persistent=true, force missed timestamps, restart, observe intended services and remove. Retain unrelated unit/data hashes. Inject ambient remote contexts, unavailable daemon, malformed accounting and prune failure; assert no remote command, no success-shaped fallback and preserved configuration. |

## Tasks

- [x] T1 `tests/test_storage_maintenance.py`, `changelog.md` - add command-fixture safety, monitoring and cleanup tests plus opt-in disposable Fedora/Btrfs scenarios; execute the unit checks and observe failure because the maintenance script does not exist (AC-01, AC-02, AC-03, AC-04, AC-05, AC-06, AC-07, AC-08).
      Evidence: The focused unittest run executed 14 tests with 20 failing assertions/subcases and one opt-in skip, all against the missing script. The opt-in Fedora fixture booted with systemd and failed at copying the missing script; its owned container was removed. Pylance reported no Python syntax errors. Manual documentation-impact review found no implemented public behavior yet; the changelog records the new tests.
- [x] T2 `bash/fedora/storage_maintenance.sh`, `tests/test_storage_maintenance.py`, `docs/fedora-storage-guard.md`, `bash/readme.md`, `changelog.md` - implement the accepted preparation, cleanup, monitoring and native-unit setup; the T1 unit tests, Bash syntax, focused ShellCheck and opt-in Fedora/Btrfs scenarios pass, including native Go builds and calendar/reboot/removal checks (AC-01, AC-02, AC-03, AC-04, AC-05, AC-06, AC-07, AC-08).
      Evidence: The full focused unittest run with `PDS_STORAGE_INTEGRATION=1` passed 19 tests. Native red/green iterations caught privileged subvolume detection, a read-only user-service sandbox, restrictive-umask staging and systemd argument expansion. Bash syntax, focused ShellCheck and the repository's existing bootstrap/CLI syntax and Makefile-help checks pass. Manual documentation-impact review matched all script modes, schedules, exit codes and preservation boundaries to the user guide and Bash index. Criteria await the independent committed-state review.
- [x] T3 `bash/fedora/storage_maintenance.sh`, `tests/test_storage_maintenance.py`, `docs/fedora-storage-guard.md`, `changelog.md` - reproduce R-2 F-01 for ambient and persisted Go flags, then isolate native cleanup from those flags without changing user configuration; direct preparation, direct cleanup and the installed user service preserve module markers and the full focused/native suite passes (AC-03, AC-08).
      Evidence: Both command fixtures and the native persisted-flag case first reproduced module deletion. After command-local env isolation, all 22 focused/native tests passed. Native preparation, direct cleanup and an installed user service preserved module markers and the Go settings-file hash with `GOFLAGS=-modcache` configured. Bash syntax and focused ShellCheck pass. Manual documentation-impact review updated the guide's isolation contract; R-2 remains unchanged pending re-review.
- [ ] T4 `tests/test_storage_consumers.py`, `tests/test_storage_maintenance.py` - add command-fixture retention/audit/uv-eligibility tests and disposable native container/package/service preservation scenarios; observe failures before the companion and extra units exist (AC-09, AC-10, AC-11, AC-12).
- [ ] T5 `bash/fedora/storage_consumers.sh`, `bash/fedora/storage_maintenance.sh`, `tests/test_storage_consumers.py`, `tests/test_storage_maintenance.py`, `docs/fedora-storage-guard.md`, `bash/readme.md`, `changelog.md` - implement host-confined native retention, complete bounded reports and managed daily units; focused shell checks plus fixture/native regressions preserve protected markers and pass (AC-01, AC-02, AC-03, AC-04, AC-05, AC-06, AC-07, AC-08, AC-09, AC-10, AC-11, AC-12).

## Open Questions

None.

## Review Log

| Date | Review | Kind | Commit | Model | Isolation | Outcome |
| --- | --- | --- | --- | --- | --- | --- |
| 2026-11-11 | R-1 | spec | `64464540e5510f3bc2d66aba09819842a9f7dc56` | unknown | procedural | No findings; model identity not attested |
| 2026-11-11 | R-1 | spec | `64464540e5510f3bc2d66aba09819842a9f7dc56` | n/a | n/a | accepted by owner |
| 2026-11-11 | R-2 | implementation | `63b87884abe8ccfbb3d3bc3234d857c7c157e078` | unknown | procedural | Six criteria met; AC-03 and AC-08 not met; blocking F-01; model identity not attested |
| 2026-11-12 | R-3 | implementation | `28bbadca764f060d5ddb5cb6f4516e3a918813db` | unknown | procedural | All eight Go-only criteria met; model identity not attested; broader storage scope requested afterward |
| 2026-11-12 | R-4 | spec | `47b18f429fa6038d1b3b548b5374a7d85460bddd` | unknown | procedural | Blocking uv environment-preservation conflict and byte-unit correction; model identity not attested |
| 2026-11-12 | R-5 | spec | `02f884eff2e6e26cc0e80232a5d868699604f6b3` | unknown | procedural | No findings after uv eligibility and explicit-byte fixes; model identity not attested |
| 2026-11-12 | R-5 | spec | `02f884eff2e6e26cc0e80232a5d868699604f6b3` | n/a | n/a | accepted by owner |

### R-1

NO FINDINGS

### R-2

CRITERION: AC-01 After approved Go cache-subvolume preparation, future home snapshots omit Go cache contents while live application paths, ownership, source files and the independent backup schedule and retention remain intact.
VERDICT: met
EVIDENCE: At 63b87884abe8ccfbb3d3bc3234d857c7c157e078, executed PYTHONDONTWRITEBYTECODE=1 PDS_STORAGE_INTEGRATION=1 PDS_STORAGE_TEST_IMAGE=pds-storage-fixture:1b889891 python3 -m unittest discover -s tests -p test_storage_maintenance.py -v, with TMPDIR outside the repository. All 19 tests passed. Native assertions verified exclusion after an actual Go build, unchanged cache path, UID/GID/mode, project-source hash and backup configuration. An additional disposable native scenario preserved an enabled btrbk timer and its service, timer and retention-configuration hashes through preparation, restart and uninstall. No live backup operation was executed.

CRITERION: AC-02 Scheduled filesystem monitoring leaves application/cache contents, allocation profiles and block-group placement unchanged while surfacing a reserve breach despite abundant aggregate free space, with the documented status and notification outcome.
VERDICT: met
EVIDENCE: At 63b87884abe8ccfbb3d3bc3234d857c7c157e078, executed fixtures reported 141566332928 aggregate available bytes alongside 1048576 device-headroom bytes, returning 1 with an explicit reserve warning and skipped-notification outcome. Healthy measurements returned 0; measurement and notification failures returned 2. A separately executed installed native monitor preserved chunk-tree and application/cache/backup hashes. Desktop delivery outcomes used command fixtures, not a real desktop.

CRITERION: AC-03 Unsafe, busy, malformed or unsuccessful cache-preparation and cleanup attempts preserve source/module/profile data and cannot return success when a required check or cleanup fails.
VERDICT: not met
EVIDENCE: At 63b87884abe8ccfbb3d3bc3234d857c7c157e078, baseline safety tests passed, but independent native probes contradicted module preservation. After the disposable user ran go env -w GOFLAGS=-modcache, both prepare-go-cache and cleanup-go returned 0 while deleting ~/go/pkg/mod/review-module/keep. Project and profile markers remained. See F-01.

CRITERION: AC-04 The installed read-only monitor survives reboot, catches a missed calendar run, remains singular after reinstall, and can be removed without affecting application data or unrelated timers.
VERDICT: met
EVIDENCE: At 63b87884abe8ccfbb3d3bc3234d857c7c157e078, the native lifecycle test passed repeated installation, unit verification, restart and preservation checks on uninstall. Independently aged the root timer stamp by two days and restarted its disposable systemd container. ExecMainStartTimestampMonotonic advanced from 626091333 to 626964980; the monitor returned Result=success and ExecMainStatus=0. Inspected OnCalendar=hourly and Persistent=true; systemd-analyze calendar --iterations=4 hourly confirmed hourly cadence. This was a container/systemd restart, not a live-host reboot.

CRITERION: AC-05 The maintenance script works directly from a Fedora checkout and its installed copy, while ordinary sourcing has no side effects and existing PDS commands retain their behavior.
VERDICT: met
EVIDENCE: At 63b87884abe8ccfbb3d3bc3234d857c7c157e078, Bash syntax, focused ShellCheck and all 19 focused tests passed. Disposable Fedora execution exercised checkout preparation/cleanup and installed monitor/cleanup services. Sourcing preserved options and traps without invoking tools. Existing CLI help/info matched before and after; diff inspection confirmed CLI dispatch and loaders were unchanged. Live installation and enforcing-SELinux behavior were not tested.

CRITERION: AC-06 Monitoring exposes the documented cache-budget breaches without deleting recent Go objects, installed browsers, profiles or snapshot-retained data, and redirected/plain output retains explicit partial and failure outcomes.
VERDICT: met
EVIDENCE: At 63b87884abe8ccfbb3d3bc3234d857c7c157e078, an additional executed fixture measured 38.45 GiB of Go cache and 16 GiB of browser cache. Captured output reported both budget warnings and returned 1 without ANSI escapes or Go cleanup calls; recent Go-object, browser, module and profile markers remained unchanged. Baseline incomplete/inaccessible measurements returned 2. Native monitoring preserved the chunk tree and application/cache hashes; the lifecycle scenario retained its home snapshot.

CRITERION: AC-07 After an approved cache-subvolume migration, native Go cache cleanup reclaims filesystem space even while new home snapshots are retained, without changing application paths, ownership or live source files.
VERDICT: met
EVIDENCE: At 63b87884abe8ccfbb3d3bc3234d857c7c157e078, the executed native lifecycle test prepared the subvolume, built a real Go program, retained a parent-home snapshot, ran native cleanup and synced Btrfs. Its assertion observed increased filesystem available bytes, unchanged application paths/ownership and matching project-source and backup hashes. The sparse 21 GiB object triggered the apparent-size budget; it was not evidence of 21 GiB physically reclaimed.

CRITERION: AC-08 The explicitly enabled user cleanup schedule catches missed runs and clears an over-budget Go build cache through the native command while preserving module caches and reporting busy, failed and unsupported cleanup attempts.
VERDICT: not met
EVIDENCE: At 63b87884abe8ccfbb3d3bc3234d857c7c157e078, baseline user-timer catch-up and busy/error/refusal tests passed. Inspected OnCalendar=*-*-* 00/4:15:00 and Persistent=true; systemd-analyze confirmed four-hour intervals at minute 15. However, an independently executed installed user service with persistent GOFLAGS=-modcache cleared an over-budget cache and deleted the module marker while reporting Result=success and ExecMainStatus=0. See F-01.

FINDING: F-01
KIND: factual
SEVERITY: blocking
WHERE: bash/fedora/storage_maintenance.sh:265 and bash/fedora/storage_maintenance.sh:346
EVIDENCE: Both native clean invocations constrain GOCACHE, GOCACHEPROG and GOTOOLCHAIN but inherit effective GOFLAGS, including persistent go env configuration. In disposable Fedora at 63b87884abe8ccfbb3d3bc3234d857c7c157e078, go env -w GOFLAGS=-modcache caused preparation and direct cleanup to delete module-cache data while returning 0. The installed user service independently reproduced deletion and reported success. Thus the apparently fixed clean -cache command also performs explicitly excluded module-cache removal.
PROPOSAL: Constrain effective Go flags for both preparation and cleanup, including persistent configuration, so additional cleanup targets cannot be selected. Add native direct-command and installed-user-service regression checks asserting module-cache preservation with GOFLAGS=-modcache configured.

### R-3

CRITERION: AC-01 After approved Go cache-subvolume preparation, future home snapshots omit Go cache contents while live application paths, ownership, source files and the independent backup schedule and retention remain intact.
VERDICT: met
EVIDENCE: At 28bbadca764f060d5ddb5cb6f4516e3a918813db, the executed native Fedora/Btrfs lifecycle test verified cache exclusion from a retained home snapshot, unchanged application path, preserved UID/GID/mode and unchanged source and backup-configuration hashes. Verification used disposable storage, not the live host.

CRITERION: AC-02 Scheduled filesystem monitoring leaves application/cache contents, allocation profiles and block-group placement unchanged while surfacing a reserve breach despite abundant aggregate free space, with the documented status and notification outcome.
VERDICT: met
EVIDENCE: At 28bbadca764f060d5ddb5cb6f4516e3a918813db, executed fixtures reported the constrained device despite abundant aggregate space and verified notification success, absence and failure outcomes. Native monitoring preserved the complete chunk-tree dump, cache measurements/content digest and protected-data hashes. A failed native desktop delivery returned documented status 2; installed monitoring produced journal measurements.

CRITERION: AC-03 Unsafe, busy, malformed or unsuccessful cache-preparation and cleanup attempts preserve source/module/profile data and cannot return success when a required check or cleanup fails.
VERDICT: met
EVIDENCE: At 28bbadca764f060d5ddb5cb6f4516e3a918813db, executed tests covered unsafe paths/layouts, unknown files, busy builds, missing tools, malformed measurements, cleanup failure and interrupted preparation. Native ambient/persisted GOFLAGS=-modcache regressions preserved modules and Go settings. Additional native probes verified custom configured GOCACHE refusal without changing settings and safe preparation with hostile GOFLAGS, GOCACHEPROG and GOTOOLCHAIN settings.

CRITERION: AC-04 The installed read-only monitor survives reboot, catches a missed calendar run, remains singular after reinstall, and can be removed without affecting application data or unrelated timers.
VERDICT: met
EVIDENCE: At 28bbadca764f060d5ddb5cb6f4516e3a918813db, native lifecycle tests passed reinstall, conflicting-file refusal, unit validation and selective uninstall with preserved unrelated timers/data. An additional probe aged the hourly Persistent=true timer stamp, restarted the disposable systemd container and observed its new trigger at 2026-11-12 00:44:00 UTC with journal measurements. This establishes disposable restart behavior, not a live Fedora reboot or enforcing-SELinux installation.

CRITERION: AC-05 The maintenance script works directly from a Fedora checkout and its installed copy, while ordinary sourcing has no side effects and existing PDS commands retain their behavior.
VERDICT: met
EVIDENCE: At 28bbadca764f060d5ddb5cb6f4516e3a918813db, bash -n and ShellCheck passed. Unittest discovery executed all 22 tests successfully, including native checkout/installed execution, unchanged sourcing options/traps with no tool execution and identical existing CLI help/info output. Test scratch paths alone were redirected in memory outside the checkout and within disposable containers; repository files were not edited.

CRITERION: AC-06 Monitoring exposes the documented cache-budget breaches without deleting recent Go objects, installed browsers, profiles or snapshot-retained data, and redirected/plain output retains explicit partial and failure outcomes.
VERDICT: met
EVIDENCE: At 28bbadca764f060d5ddb5cb6f4516e3a918813db, executed fixtures verified browser-budget warnings, plain captured output, absent-cache reporting and explicit measurement failures. Additional native monitoring reported a newly populated 21 GiB apparent Go-cache breach while preserving cache content, browser/profile/source/module hashes and the chunk tree. Inspection confirmed check mode invokes no cleanup or snapshot deletion.

CRITERION: AC-07 After an approved cache-subvolume migration, native Go cache cleanup reclaims filesystem space even while new home snapshots are retained, without changing application paths, ownership or live source files.
VERDICT: met
EVIDENCE: At 28bbadca764f060d5ddb5cb6f4516e3a918813db, the executed native lifecycle test prepared the nested cache, built a real Go program and retained a parent home snapshot. After native cleanup and filesystem sync, Btrfs-reported free bytes increased; cache exclusion, path, ownership and source-hash assertions passed. Evidence is from owned two-device loopback Btrfs storage.

CRITERION: AC-08 The explicitly enabled user cleanup schedule catches missed runs and clears an over-budget Go build cache through the native command while preserving module caches and reporting busy, failed and unsupported cleanup attempts.
VERDICT: met
EVIDENCE: At 28bbadca764f060d5ddb5cb6f4516e3a918813db, native tests passed direct and installed-service cleanup under ambient/persisted GOFLAGS=-modcache with modules/settings preserved. Additional probes verified the exact *-*-* 00/4:15:00 calendar and Persistent=true, then observed missed-run cleanup after disposable restart at 2026-11-12 00:44:01 UTC. Over-budget objects disappeared while modules, source, profiles, browsers and Go settings remained intact. Busy, failed and unsupported cases returned documented nonzero outcomes.

### R-4

FINDING: F-01
KIND: factual
SEVERITY: blocking
WHERE: Design: Additional consumer policy; AC-10; Test Plan AC-10
EVIDENCE: docs/internal/plans/fedora-storage-guard.md:385 requires uv cache prune, while AC-10:564 promises project/environment preservation. Released uv 0.13.7 removes all cached environments, including centralized project environments referenced by .venv links: https://github.com/astral-sh/uv/blob/0.13.7/crates/uv-cache/src/lib.rs#L710-L723. Neither offline mode nor omission of --force prevents this removal.
PROPOSAL: Require fail-closed eligibility checks protecting centralized project environments, leaving uv audit-only when preservation cannot be established. Add a native regression with a linked project environment and protected marker.

FINDING: F-02
KIND: factual
SEVERITY: should-fix
WHERE: Design: Additional consumer policy, lines 376-378
EVIDENCE: The specification calls 20GB/10GB decimal values. Buildx v0.39.0 commands/prune.go uses opts.MemBytes; Docker CLI v29.9.3 opts/opts.go:420-423 parses that type with units.RAMInBytes. These arguments therefore mean 21,474,836,480 and 10,737,418,240 bytes, contradicting the stated decimal targets.
PROPOSAL: Pass explicit values 20000000000 and 10000000000 for the specified decimal targets. Update the command expectations to verify their byte meanings.

### R-5

NO FINDINGS

## Sources

- [Btrfs balance manual](https://btrfs.readthedocs.io/en/latest/btrfs-balance.html): data/device/usage/limit filters, workspace requirements and ENOSPC limits.
- [Btrfs filesystem manual](https://btrfs.readthedocs.io/en/latest/btrfs-man5.html): defragmentation can break reflinks and increase space usage; it is excluded from recovery.
- [systemd timer manual](https://www.freedesktop.org/software/systemd/man/latest/systemd.timer.html): persistent catch-up applies to `OnCalendar` timers, not an interval-only timer.
- [Btrfs subvolumes](https://btrfs.readthedocs.io/en/latest/Subvolumes.html): nested subvolumes are excluded from nonrecursive parent snapshots; received UUIDs identify source snapshots.
- [Feature documents](https://github.com/vhco-pro/docs/blob/0e52f51f01b84eda75a976763c42d8ec0a07b544/conventions/feature-documents.md): draft, review, acceptance and evidence requirements at the existing PDS pin.
- [Docker build garbage collection](https://docs.docker.com/build/cache/garbage-collection/): native size/age retention targets and their distinction from hard quotas.
- [uv 0.10.9 cache pruning](https://github.com/astral-sh/uv/blob/0.10.9/crates/uv-cache/src/lib.rs): environment-bucket and unknown-bucket removal requires conservative eligibility checks, not just omission of `--force`.
