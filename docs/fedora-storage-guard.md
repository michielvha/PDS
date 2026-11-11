# Fedora storage maintenance

The [maintenance script](../bash/fedora/storage_maintenance.sh) manages the
default Go build cache and checks Btrfs allocation headroom. It is tested with
Fedora 43 userspace, native systemd and disposable two-device Btrfs filesystems.

| Job | Schedule | Action |
| --- | --- | --- |
| Go cleanup, as the selected user | Every four hours at 00:15, 04:15, 08:15, 12:15, 16:15 and 20:15 | Above 20 GiB apparent cache size, run `go clean -cache` |
| Filesystem check, as root | Hourly | Report per-device allocation reserve, available space, metadata utilization, device errors and cache budgets |

Both timers use `OnCalendar` and `Persistent=true`. The user timer runs while
the user manager is active and catches missed runs at the next login. Setup
does not enable lingering. The system timer does not depend on a user login.

## What stays untouched

The script does not remove source trees, Go module caches, browser installations
or profiles, snapshots, containers or volumes. It never balances, resizes or
changes filesystem profiles. It does not install packages or change backup
retention, shell profiles or persistent Go configuration.

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
systemctl list-timers pds-btrfs-headroom.timer --all --no-pager
systemctl --user list-timers pds-go-cache-clean.timer --all --no-pager
sudo bash /usr/local/libexec/pds-storage-maintenance check --user "$USER" --mount /
bash /usr/local/libexec/pds-storage-maintenance cleanup-go --user "$USER" --go "$(command -v go)"
journalctl -u pds-btrfs-headroom.service --since today --no-pager
journalctl --user -u pds-go-cache-clean.service --since today --no-pager
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

Storage warnings keep the system service in a failed state and attempt a
desktop notification for an active session. An absent session bus or notifier
is logged as skipped; a delivery error is explicit. Inspect the journal even
when no desktop session is active.

| Mode | Exit 0 | Exit 1 | Exit 2 |
| --- | --- | --- | --- |
| `check` | Within policy | Measured warning | Incomplete measurement, device error or notification failure |
| `cleanup-go` | Below-budget skip or successful native cleanup | Active build postponed cleanup | Unsafe path/layout, missing prerequisite or cleanup failure |
| `prepare-go-cache` | Prepared or already prepared | Active build postponed preparation | Refused input or failed preparation |

Preparation can also end with a signal exit code when interrupted. Do not treat
that as success. Cleanup never uses `go clean -modcache`; command-local
`GOCACHEPROG` and toolchain settings keep the operation on the selected local
cache without reconfiguring normal Go use.

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
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -p test_storage_maintenance.py -v
PDS_STORAGE_INTEGRATION=1 PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -p test_storage_maintenance.py -v
```

The opt-in test builds a digest-pinned Fedora fixture when missing. It needs a
local Docker daemon with Btrfs and loop-device support. Its root, privileged
container is a test-only exception for native Btrfs and systemd operations, not
an application runtime. Only owned loopback images are formatted; source files
are copied into the container, not mounted writable from the host.

The native scenario verifies unknown-data refusal, interrupted preparation,
ownership/mode preservation, physical reclamation while a home snapshot remains,
reinstallation, conflicting-file refusal, read-only service execution, missed
calendar catch-up across a systemd/container restart and unrelated-unit
preservation on uninstall. It does not reboot the real Fedora host.

The [feature record](internal/plans/fedora-storage-guard.md) contains the original
ENOSPC measurements, approved recovery operations and acceptance criteria.
