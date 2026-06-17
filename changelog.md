# Changelog

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
