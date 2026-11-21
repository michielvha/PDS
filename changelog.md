# Changelog

## Unreleased

### Maintenance

- Rename twelve PowerShell functions to singular, approved names, keeping each old name as an alias so existing scripts keep working: `Get-DisabledADUser`, `Update-GitRepository`, `Get-ListeningPort` (was `Get-Ports`), `Enable-RDSHost`, `Get-RDSActiveSessionReport` (was `Get-RDSActiveSessions`), `Install-ChocoPackage`, `Enable-LongPath`, `Set-NodeExtraCACert`, `Get-LogonActivity` (was `Get-AllConnections`), `Get-LogonEvent`, `Install-ShellCustomization` and `Set-StarshipConfigForEveryUser` (was `Set-StarshipConfigForAllUsers`). Fix the remaining analyzer warnings: the Chocolatey and Scoop installers are downloaded to a file and run from it instead of through `Invoke-Expression`, `Register-NativeCurl` defines `ncurl` without `Invoke-Expression`, WMI calls move to CIM, and no loop variable overwrites an automatic variable.
- Give the 43 PowerShell functions that change the system real `-WhatIf` and `-Confirm` support: each change now runs only after `ShouldProcess` agrees, with a target and action that say what would happen. A test per function shows `-WhatIf` changes nothing. `Remove-StaleADComputer` uses the common `-WhatIf` instead of its own switch, with the same output. `Set-Kubectl` and `Set-UserProfile` no longer fail when the profile does not exist yet.
- Format every PowerShell file to the analyzer settings and strip trailing whitespace. The seven files that contain non-ASCII text, such as the Starship prompt symbol and the menu icons, get a UTF-8 byte-order mark so Windows PowerShell 5.1 reads them correctly.
- Add a Pester test file for every public PowerShell function in `pwsh/tests/`, with every install, download, registry, service, firewall, cloud and directory call mocked so the suite never changes the machine it runs on. Tests for the twelve functions a later change renames already call the new names and check that the old name still works as an alias. The commented-out `Update-Env.Tests.ps1` is replaced by a real test.
- Replace the three publishing workflows with one release path. Every push runs the parts of `checks.yml` its changes need, judged over the whole branch since it left `main` and on `main` since the latest tag with a published Release (ShellCheck with the package build and install tests for packaging and Bash changes, the PowerShell checks from `pwsh-ci-action` for PowerShell changes, both for script changes, and those plus actionlint for workflow changes; Markdown alone runs nothing), then the shared version workflow tags `main`. An exact stable `v` tag runs the checks again at that version, then deploys the APT repository rebuilt from the GitHub Releases, publishes the Gallery module and creates the GitHub Release with git-cliff notes, the `.deb` and the `.exe`. Pull requests and branches publish nothing, prerelease tags release nothing, and only the release jobs receive secrets. Tags gain the `v` prefix; `gitversion.yml` and the release-notes template are removed.
- Export every PowerShell function file as its command: `Remove-StaleADComputer` and `Install-AzureKubeCLI` live in files named after them, the function template moves out of `Public` to `pwsh/templates/`, and the module loader skips Pester test files. Add the PSScriptAnalyzer settings the new CI checks use.
- Pin the PowerShell module publish and script packaging actions by full commit SHA, so their upcoming release-only versions cannot change the current release path before PDS migrates to it.

### Features

- Keep Btrfs allocation headroom from the Fedora storage maintenance: a new `balance` mode and hourly `pds-btrfs-balance` timer check per-device unallocated space against what the metadata profile needs (two devices for RAID1), aiming for 16 GiB at night and 8 GiB by day. When a device is short it balances data chunks off it in bounded, load-guarded batches. `--dry-run` previews it.
- Docker retention also prunes build cache unused for 72 hours and dangling images older than a day. Volumes and containers stay untouched.
- Add `Enable-WinRmServer` and `Disable-WinRmServer`, which prepare a Windows test host for Ansible over WinRM with NTLM authentication, also on networks classed Public, and undo it.

### Documentation

- Record the PowerShell function defects that the new tests and the Windows VM runs found and this change left open, in `docs/internal/analysis/pwsh-function-defects.md`.
- Record the verified Fedora Btrfs recovery and the accepted cache-exclusion/scheduled-cleanup policy in `docs/internal/plans/fedora-storage-guard.md`.
- Refresh the root README with platform coverage, usage examples, and light and dark project banners. Record backlog dispositions and deferred ideas in `docs/internal/analysis/readme-refresh.md`.
- Move the Debian workstation bootstrap reference to `docs/workstation-bootstrap.md` and describe its remaining validation gaps.
- Add pinned agent instructions for vh-adlc, with Copilot and Claude entry points. Preserve platform and changelog requirements from the earlier instructions.

### Fixed

- `Get-ListeningPort` works when exactly one TCP port is listening; it used to fail with an `op_Addition` error.
- Rerunning a release's APT job deploys Pages again; each attempt now uploads its own Pages artifact, where a second one with the same name made the deploy fail.
- A push whose changes select no check, such as Markdown only, still runs the version workflow; it used to be skipped with the checks. A failed selection or check still stops it.
- The release's APT job can run `scripts/build-apt-repo.sh` again: the script was committed without its executable bit, which stopped the `v0.26.0` release before its GitHub Release. The checks now fail on any script under `scripts/` that is not executable.
- `Remove-WindowsBloat -WhatIf` no longer suggests a reboot, since it changed nothing.
- `Get-AzureDevOpsLibrary` passes the access token to Git only for the duration of each clone or pull, and removes it from the remote URL of clones made earlier. `Remove-StaleADComputer` skips computers that have never logged on.
- Fix what real runs on Windows 11 exposed: `Set-AwsCli` creates the PowerShell profile when it does not exist instead of failing; `Remove-WindowsBloat` disables the per-user service templates (OneSyncSvc, PrintWorkflowUserSvc, CDPUserSvc, MessagingService) instead of failing on their per-user copies; `Install-Scoop` passes `-RunAsAdmin` in an elevated session and reports an install that did not happen; `Set-AzCli` adds each extension separately, reports any that fails, and no longer asks for the `storage` extension, whose commands are built into the Azure CLI; `Set-AutoAdminLogin` stores the password instead of the text `System.Security.SecureString`; `Set-LF` keeps each file's encoding, so a script without a byte-order mark stays without one; `Get-WindowsKey` decodes Windows 8 and later product keys correctly.
- `Get-DisabledADUser` returns the disabled users again; it failed on every call with a type conversion error. `Get-LogonActivity` and `Get-LogonEvent` read the Security log with `Get-WinEvent`, so they work on PowerShell 7. `Get-WindowsKey` uses a credential for the remote OS lookup too and returns `InstallDate` without a conversion error. `Get-RDSActiveSessionReport` writes its log to `-LogPath` explicitly.
- The scheduled Go cache cleanup now trims entries unused for 48 hours, then 24, 12 and 6 hours while the cache is over budget, and runs while Go builds are active. It used to wait for a moment with no Go build at all, which never came on a host with several build sessions, and failed for good when Go removed an entry mid-scan. Unknown entries are reported and skipped. `--dry-run` previews the trim.
- Storage cleanup jobs no longer stay failed because of a capacity warning or a desktop notification that times out. They log both and fail only on errors; the hourly check remains the alarm. An incomplete read-only scan in the daily user audit, such as a root-owned directory, is a warning there rather than a failure. The npm verification checks for aliases only in `_cacache`, the tree it verifies, so the `node_modules/.bin` links npx creates no longer make it refuse.
- `Enable-SshServer` now always creates or corrects its own firewall rule for every network profile. It used to accept any existing rule for the SSH port, including the one Windows creates for the Private profile only, which left SSH blocked on networks Windows classes as Public.

### Added

- Make the public key optional in PowerShell `Enable-SshServer`. Without `-PublicKey` or `-PublicKeyPath` it only installs and starts the OpenSSH server and opens the firewall, so users sign in with their Windows password. `-DisablePasswordAuthentication` still requires a key so the machine cannot be locked out.
- Add `install_virtio_win_iso` and `enable_virtio_win_iso_updates` to keep the VirtIO driver ISO for Windows guests current in Proxmox VE (or other) ISO storage. Downloads follow upstream's stable link over HTTPS only, skip unchanged versions, and replace the ISO atomically. A weekly cron job runs the packaged function, so APT upgrades update the logic.
- Add PowerShell `Enable-SshServer` to install and start Windows OpenSSH server, allow the SSH port through the firewall and authorize public keys. Administrator keys go in `administrators_authorized_keys` with the ACLs sshd requires. Port, default shell and password authentication are configurable.
- Add `bash/fedora/storage_maintenance.sh` with explicit Go-cache subvolume preparation, four-hour native cleanup above 20 GiB, hourly read-only Btrfs checks and managed systemd install/removal. Preserve source/module/profile data and backup retention; never balance or delete snapshots automatically.
- Add daily local Docker/Podman image retention with a seven-day creation cutoff, explicit Docker build-cache byte targets, native npm verification and version/layout-guarded uv pruning. Report volumes, builders, review directories, worktrees, module and editor caches without deleting them.
- Add command-fixture and disposable Fedora/Btrfs regression scenarios for storage maintenance, including the observed failing baseline before implementation.
- Render the official GitHub organization logo silhouettes as plain ASCII above the VHCO and Stackweaver FIGlet Big wordmarks; preserve EdgeForge artwork.

- Test the actual nFPM artifact name, including Debian-normalized prerelease versions, and reject missing or ambiguous package inputs.
- Map the Zsh `k` alias to kubectl's registered completion so current kubectl releases work for image users and normal installations through `install_kubectl`.
- Add explicit shared-image kubectl/Krew installation, verified Krew release inputs, and fresh-user/failure regression checks; retain ordinary per-user installation.
- Expose Krew archive versions/checksums and the test container digest to managed dependency updates; updates remain reviewable pull requests.
- Check the built image-provisioning package on pull requests, fail relevant shell warnings, and include packaged configuration/test changes in CI and release triggers.
- Keep pull-request version calculation in dry-run mode, freeze existing publisher action revisions without upgrades, and gate package publication on image-provisioning checks.
- Restrict check jobs to read-only tokens and remove persisted checkout credentials. Version calculation stays read-only; the existing release job creates the tag at the checked commit after package tests pass.
- Share one verified nFPM download between local and publisher checks and fold package coverage into the existing workflow.
- Package the existing Zi configuration and unchanged Powerlevel10k preset for current and future users.
- Add configurable Debian/Ubuntu MOTD setup and a pinned-package image provisioning example.
- Add isolated tests that install the actual Debian package and verify image provisioning helpers.

### Fixed

- Refuse npm verification through subtree aliases/mounts, keep user executables out of root-service resolution, and reject malformed container byte accounting before pruning. Add native over-target BuildKit reclamation and data-preservation regressions.
- Isolate native cache-maintenance children from ambient and persisted Go flags so `GOFLAGS=-modcache` cannot extend cleanup into module storage. Preserve the user's Go configuration.
- Keep ordinary Krew installs per user when an image profile exports the shared root, export shell-local custom roots, and keep root/PATH selection together when switching roots.
- Load installed libraries and resolve their imports/assets in Zsh without downloads or changes to caller options.
- Guard the Zsh filename fallback when Bash has no source metadata.
- Simplify temporary Zsh configuration cleanup and remove a redundant pipe from cron migration.

- Reuse existing Zi installs and report missing dependencies without interactive prompts.
- Load local packaged helpers without implicit network downloads and report initialization failures.
- Consolidate sudoers and Azure implementations while retaining local compatibility imports.
- Correct package paths and replace obsolete Oh My Zsh references in CLI help.
- Correct existing lint findings in the Zsh font-profile pattern and Arch cleanup argument handling.

## 2026-06-17

### Added

- **configure_libvirt_pool / define_concealed_vm / export_concealed_vm / harden_concealed_vm / attach_gpu_passthrough** (`bash/arch/virtualisation.sh`): persist the concealed Windows VM setup so it can be recreated on a fresh Arch box without re-running AutoVirt's interactive menu or hand-editing XML. `configure_libvirt_pool` repoints the `default` storage pool at `/home/VMs`; `define_concealed_vm` defines the domain from `bash/arch/concealed-vm.xml.template` (env-var substitution, refuses to define while host-specific GPU placeholders remain); `export_concealed_vm` snapshots a working domain back into the template; `harden_concealed_vm` applies the Phase 7.5 CPU/feature hardening via `virt-xml` (disables vmx/svm/hypervisor, requires invtsc/topoext, pmu on); `attach_gpu_passthrough` adds the dGPU (VGA + audio) with rom bar off and strips the virtual display.
- **concealed-vm.xml.template** (`bash/arch/`): reproducible libvirt domain with the anti-VM-detection hardening from the docs Phase 7.5 review baked in (memballoon none, invtsc/topoext, hypervisor/svm disabled, pmu on, rom bar off, e1000e, spoofed disk model/serial).

### Changed

- **docs/gpu-passthrough-windows-vm.md**: added Phase 7.5 (audit & harden the generated domain XML — mentor review), and pointed Phase 5/6 at the new PDS functions instead of ad-hoc `virsh` commands.

## 2026-06-01

### Changed

- **Set-AzureCLI**: Now disables the Windows Web Account Manager (WAM) broker via `az config set core.enable_broker_on_windows=false`, reverting `az login` to the browser-based authentication flow and avoiding the "User cancelled the Accounts Control Operation" account picker.

## 2026-02-16

### Fixed

- **APT repository GPG key format**: Changed `gpg --armor --export` to `gpg --export` (binary format) in the `build-apt-package.yml` pipeline. The `.gpg` file extension requires binary OpenPGP format per `apt-secure(8)`, but the key was being exported in ASCII-armored format, causing `NO_PUBKEY` errors when clients ran `apt update`.

## Engineering workflow

- Pin the shared engineering conventions and retain the existing project instructions in AGENTS.md.

- Add regression checks for bundled MOTD presets, custom banners and invalid-selection preservation.

- Bundle VHCO, Stackweaver and preserved EdgeForge text banners behind `setup_motd_preset`, retaining custom-file support.

- Add real OpenSSH authentication and noninteractive update/conffile/lock regression tests before changing the baseline helpers.

- Configure a repeatable noninteractive nightly updater and a validated no-reload SSH policy through shared helpers.
