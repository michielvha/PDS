# Changelog

## Unreleased

### Added

- Add text-only hexagonal VH and SW logo approximations above the VHCO and Stackweaver FIGlet Big wordmarks; preserve EdgeForge artwork.

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
