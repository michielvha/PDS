# Fedora storage maintenance

The [maintenance script](../bash/fedora/storage_maintenance.sh) manages the
default Go build cache and keeps Btrfs allocation headroom. It is tested with
Fedora 43 userspace, native systemd and disposable two-device Btrfs filesystems.
It is the one PDS storage-maintenance system: every job below is installed,
checked and removed by the same script, and its units all start with `pds-`.

| Job | Schedule | Action |
| --- | --- | --- |
| Go trim, as the selected user | Every four hours at 00:15, 04:15, 08:15, 12:15, 16:15 and 20:15 | Above 20 GiB apparent cache size, delete cache entries unused for 48 hours, then 24, 12 and 6 hours until the cache is under budget |
| Filesystem check, as root | Hourly | Report per-device allocation reserve, available space, metadata utilization, device errors and cache budgets |
| Headroom balance, as root | Hourly at half past | Keep enough devices with unallocated space for a new metadata chunk; balance data chunks off the short device in small batches |
| Docker retention, as root | Daily at 04:45 | Prune build cache unused for 72 hours, then target 20 GB with 10 GB reserved; prune dangling images older than a day and unreferenced images created more than seven days ago |
| Developer-cache maintenance, as the user | Daily at 05:15 | Prune old unreferenced local Podman images, verify npm, eligibility-check uv and report developer storage |

All timers use `OnCalendar` and `Persistent=true`. User timers run while
the user manager is active and catches missed runs at the next login. Setup
does not enable lingering. System timers do not depend on a user login.

## What stays untouched

The script does not remove source trees, Go module caches, browser installations
or profiles, snapshots, containers or volumes. Its balance moves only data chunks,
in bounded batches; it never balances metadata, resizes, adds or removes devices,
or changes filesystem profiles. It does not install packages or change backup
retention, shell profiles or persistent Go configuration. It leaves `/tmp` to
Fedora's own `systemd-tmpfiles` age policy.

## Keep Btrfs allocation headroom

A multi-device filesystem with RAID1 metadata needs unallocated space on two
devices at once to add a metadata chunk. When the smaller device is fully
allocated, every write that needs new metadata stalls with ENOSPC, even while
`df` still shows free space. The metadata percentage alone does not show this;
per-device unallocated space does.

The balance job reads `btrfs filesystem usage -b -T` and counts the devices
with at least the target unallocated space. It needs as many as the metadata
profile keeps copies: two for RAID1, RAID10 and RAID5, three for RAID1C3 and
RAID6, four for RAID1C4 and one for single or DUP. On a single-device pool
with DUP metadata both copies go on that device, so it alone needs the target,
and the balance compacts data chunks on it to free space.

| When | Target per device |
| --- | --- |
| 01:00 to 05:59 | 16 GiB |
| Other hours | 8 GiB, the same reserve the hourly check warns about |
| Manual run with `--target-gib N` | N GiB at any hour |

If too few devices reach the target, it balances data chunks off the device
with the least unallocated space:

1. It stops if another balance is already running.
2. It waits while the one-minute load average is at or above the number of CPUs,
   checking ten times with the pause in between, and otherwise postpones to the next run.
3. It runs `btrfs balance start -ddevid=ID,usage=U,limit=5`, starting at
   `usage=20` and moving to 50 and 90 only when a batch relocates nothing.
4. It pauses 60 seconds and measures again.
5. It stops when the target is met, after 12 batches, or when no chunk below
   90 percent use remains.

Preview a run without changing anything:

```bash
sudo bash /usr/local/libexec/pds-storage-maintenance balance --user "$USER" --mount / --dry-run
sudo bash /usr/local/libexec/pds-storage-maintenance balance --user "$USER" --mount / --target-gib 24 --dry-run
```

`--max-batches N` and `--pause SECONDS` bound a manual run further. If the
whole pool is close to full, balancing cannot create space; free data or add
capacity.

The [consumer companion](../bash/fedora/storage_consumers.sh) handles the larger
cache classes through native commands. It never calls `system prune`,
`volume prune`, container deletion, worktree removal or recursive archive
deletion. An unattached volume can still contain a database. Names such as
`builders-*` or `stackweaver-maintenance-*` do not establish disposability.

Docker retention is bound to the local Unix socket and default builder.
Podman is explicitly local and rootless. Remote endpoints and inherited
builder selection cannot redirect these jobs. No daemon restart or
replacement of its configuration is needed.

Image retention uses the engines' `until=168h` creation cutoff. A recently used
but now unreferenced old image may be removed; referenced images, including
references from stopped containers, remain. Discarded images may need another
download or build. BuildKit receives explicit byte limits `20000000000` and
`10000000000`. These targets cannot force reclamation of in-use cache.

Npm runs native verification, which may retain a large valid content/npx cache.
Verification is refused if its cache subtree contains symlinks, nested mounts
or an incomplete traversal. A top-level cache path alone does not establish
confinement.
Uv pruning is allowed only for a verified version (initially 0.10.9), a canonical
recognized cache layout, no `environments-*` bucket and no active uv process.
Unknown versions, buckets or symlinks are reported and skipped. A bucket that
contains project environments is never removed to make eligibility pass.
The host's observed `environments-v2` bucket means uv pruning will be skipped.
Eligible pruning remains offline, non-forced and without CI cache shortcuts.

Daily audit output includes Docker/Podman image/volume use, unattached Docker
volume count, builders/code caches, review archives, maintenance/security
directories, Claude worktrees and native Git lock/registration information,
Go modules, npm, uv, Zed cache/data and the remaining user cache. These are
read-only categories. Overlapping totals must not be added together.
Each directory scan is bounded to 30 seconds; permission errors and timeouts
are incomplete results, never zero-sized successes.

## Go cache trim

Go refreshes a cache entry's modification time when it uses the entry and the
time is more than an hour old. An entry untouched for several hours is not part
of a running build, so the trim runs while builds are active. It deletes only
files named like Go cache entries inside the cache's two-character shard
directories. Anything else, including a nested filesystem, is reported with
`SKIP` and left alone, and does not fail the job. An entry that disappears
while the trim runs, because Go trimmed it first, is not an error.

Preview the trim:

```bash
bash /usr/local/libexec/pds-storage-maintenance cleanup-go --user "$USER" --go "$(command -v go)" --dry-run
```

Go cache preparation is an explicit exception to normal backup coverage: the
default cache becomes a nested Btrfs subvolume at the same path. Parent home
snapshots omit its contents because Btrfs snapshots are nonrecursive. This
allows later cleanup to reclaim bytes instead of leaving them pinned by home
snapshots. Existing snapshots keep any historical cache extents they already
reference.

Only `$HOME/.cache/go-build` is managed. Preparation refuses a different
configured `GOCACHE`, symlink paths, explicit mount aliases, unknown cache
contents and active Go builds. It clears the rebuildable cache before replacing
the empty directory, preserving UID, GID and mode. Expect a cold rebuild.
Unknown data, including unsupported cache layouts, is not removed automatically.

## Prepare and install

Use a checkout containing this feature. Run preparation as the normal user,
not through `sudo`, during an idle build window:

```bash
script="$PWD/bash/fedora/storage_maintenance.sh"
go_bin="$(command -v go)"
bash "$script" prepare-go-cache --user "$USER" --go "$go_bin"
sudo bash "$script" install --user "$USER" --mount / --go "$go_bin"
```

Supply the existing stable Go executable path. For Homebrew this is normally
its `bin/go` symlink, not a version-specific Cellar path. The installer copies
the script to `/usr/local/libexec/pds-storage-maintenance`; timers do not rely
on the checkout remaining in place.

The script requires existing Bash/GNU coreutils, Btrfs tools, util-linux,
systemd, procps and Go. Missing prerequisites are errors. Reinstallation is
idempotent for the same user and mount; different configuration or conflicting
unowned files are refused.

If preparation is interrupted, it reports its staging directory and returns a
failure. It does not overwrite a directory recreated by a concurrent writer.
Inspect any reported staging directory before deleting it or retrying. Do not
clear the whole cache tree: other applications can store work there.

## Check the result

```bash
systemctl list-timers pds-btrfs-headroom.timer pds-btrfs-balance.timer --all --no-pager
systemctl --user list-timers pds-go-cache-clean.timer --all --no-pager
systemctl list-timers pds-cache-docker.timer --all --no-pager
systemctl --user list-timers pds-cache-user.timer --all --no-pager
sudo bash /usr/local/libexec/pds-storage-maintenance check --user "$USER" --mount /
bash /usr/local/libexec/pds-storage-maintenance cleanup-go --user "$USER" --go "$(command -v go)"
journalctl -u pds-btrfs-headroom.service --since today --no-pager
journalctl -u pds-btrfs-balance.service --since today --no-pager
journalctl --user -u pds-go-cache-clean.service --since today --no-pager
journalctl -u pds-cache-docker.service --since today --no-pager
journalctl --user -u pds-cache-user.service --since today --no-pager
```

The check warns below 8 GiB unallocated on any participating device or below
10% aggregate available space. Eight GiB is a policy margin, not a Btrfs hard
minimum. A high metadata percentage alone is not proof of ENOSPC; the report
includes allocation headroom.

Go and browser budgets use apparent file bytes from `du -sb`, not exclusive
physical extent usage. Btrfs compression, sharing and metadata replication can
make these numbers differ from `df`. The Go budget is a cleanup trigger, not a
quota. Growth between checks can exceed it. The combined Playwright, Playwright
MCP and Puppeteer warning budget is 15 GiB; monitoring never deletes browsers.

Storage warnings keep the hourly check service in a failed state and attempt a
desktop notification for an active session. An absent session bus or notifier
is logged as skipped; a failed delivery is logged as a warning. Inspect the
journal even when no desktop session is active.

The cleanup jobs report the same warnings in their journal but succeed once
they have done what they safely can. Only errors fail them, so the hourly check
is the one alarm.

Daily consumer warnings use these limits. They do not authorize deletion of
report-only data:

| Class | Warning |
| --- | --- |
| Docker build cache | Above 30 GB |
| Docker or Podman images | Above 40 GB per engine |
| Container volumes | Above 30 GB, or more than 50 unattached Docker volumes |
| Builders/code caches | Above 20 GiB |
| Review/archive/worktree class | Above 10 GiB |
| Go modules | Above 20 GiB |
| Npm, uv or Zed class | Above 5 GiB |
| Whole user cache | Above 50 GiB |

| Mode | Exit 0 | Exit 1 | Exit 2 |
| --- | --- | --- | --- |
| `check` | Within policy | Measured warning | Incomplete measurement or device error |
| `balance` | Enough devices have the target headroom | Still short after the bounded batches, another balance running, a busy host, or a dry run that would balance | Degraded or unreadable filesystem, unknown metadata profile or failed balance |
| `cleanup-go` | Below-budget skip or completed trim, including a remaining over-budget warning | Not used | Unsafe cache path, missing prerequisite or failed deletion |
| `prepare-go-cache` | Prepared or already prepared | Active build postponed preparation | Refused input or failed preparation |
| Audit operations | Healthy or explicit optional-tool skip | Measured capacity warning | Failed native command, invalid accounting or incomplete scan |
| Cleanup operations | Retention ran, with or without capacity warnings | Not used | Failed native command, invalid accounting or incomplete scan |

Preparation can also end with a signal exit code when interrupted. Do not treat
that as success. Preparation uses `go clean -cache`, never `go clean -modcache`;
command-local `GOENV=off`, empty `GOFLAGS`/`GOCACHEPROG` and a local toolchain keep
the operation on the selected cache. This prevents ambient or persisted flags from
adding other cleanup targets. The scheduled trim does not run Go. Preparation still reads the user's configured `GOCACHE`
before migration; the configuration file and normal Go preferences are not
modified.

## Remove the jobs

```bash
sudo bash /usr/local/libexec/pds-storage-maintenance uninstall --user "$USER" --mount /
```

Removal stops and removes only PDS-owned units and the installed copy. Cache
contents and the nested cache subvolume remain. Returning that path to ordinary
home-snapshot coverage would require a separately planned migration.

## Verification

Run the focused checks from the repository root:

```bash
bash -n bash/fedora/storage_maintenance.sh
shellcheck bash/fedora/storage_maintenance.sh
shellcheck -x -P SCRIPTDIR bash/fedora/storage_consumers.sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -p test_storage_maintenance.py -v
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -p test_storage_consumers.py -v
PDS_STORAGE_INTEGRATION=1 PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -p test_storage_maintenance.py -v
```

The opt-in test builds a digest-pinned Fedora fixture when missing. It needs a
local Docker daemon with Btrfs and loop-device support. Its root, privileged
container is a test-only exception for native Btrfs and systemd operations, not
an application runtime. Only owned loopback images are formatted; source files
are copied into the container, not mounted writable from the host.

A second native scenario writes and partly deletes data on the two-device
loopback filesystem, previews a balance and runs two bounded batches that
relocate real chunks.

The native scenario verifies unknown-data refusal, interrupted preparation,
ownership/mode preservation, physical reclamation while a home snapshot remains,
reinstallation, conflicting-file refusal, read-only service execution, missed
calendar catch-up across a systemd/container restart and unrelated-unit
preservation on uninstall. It does not reboot the real Fedora host.
Additional native regressions configure persisted `GOFLAGS=-modcache` and an
inherited service environment, then verify preparation, direct cleanup and the
installed service leave module data and the Go settings file intact.

The [feature record](internal/plans/fedora-storage-guard.md) contains the original
ENOSPC measurements, approved recovery operations and acceptance criteria.
