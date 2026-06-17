# Concealed Windows VM for malware analysis (anti-VM-detection)

Goal: a Windows 11 guest that **cannot tell it is a VM**, so that malware which
refuses to detonate under virtualisation (a near-universal evasion technique)
runs as if on bare metal. Concealment is the whole point here — GPU passthrough
is just one of several layers that make the guest look physical, not the
headline feature.

Reference setup this was written for: **Intel 14700K + RTX 4070 Ti SUPER**, Arch
+ KDE, booting a **Unified Kernel Image via rEFInd** (no GRUB), host desktop on
the **Intel iGPU**, the dGPU reserved for the VM.

> **Tooling.** The heavy lifting is done by **AutoVirt**
> (`github.com/Scrut1ny/AutoVirt`, cloned to `~/AutoVirt` by PDS's
> `setup_autovirt`). Its menu — `[1] Virtualization Setup`, `[2] QEMU (Patched)`,
> `[3] EDK2 (Patched)`, `[4] GPU Passthrough`, `[7] Deploy Auto/Unattended XML`
> — is built around hiding the hypervisor. We do NOT hand-build the VM in
> virt-manager: a default virt-manager VM leaks dozens of VM tells (KVM CPUID
> signature, `kvmclock`, QEMU SMBIOS strings, PS/2 devices, virtual NIC OUI,
> hypervisor-present bit) and malware will fingerprint every one of them.
>
> PDS contributes one piece: `configure_vfio_passthrough` (in
> `bash/arch/virtualisation.sh`). AutoVirt's `[4]` only knows GRUB /
> systemd-boot / Limine and **exits** on a UKI+rEFInd box; PDS covers that gap by
> patching `/etc/kernel/cmdline` and rebuilding the UKI.

## What "concealed" actually means here

AutoVirt's `deploy.sh` (`[7]`) generates a libvirt domain whose every knob is set
to erase a VM tell. The ones that matter for malware evasion:

| Layer | What it hides | Set by |
|---|---|---|
| `kvm.hidden.state=on` | KVM CPUID signature (`KVMKVMKVM` @ `0x40000000`) | `[7]` |
| hypervisor-present bit cleared (`CPUID.1:ECX[31]`) | the universal "I'm a VM" flag | `[7]` (Hyper-V off) |
| `vmport.state=off` | VMware backdoor I/O port `0x5658` | `[7]` |
| `msrs.unknown=fault` | PV MSRs that linger after `kvm=off` (injects `#GP`) | `[7]` |
| `kvmclock`/`hypervclock` off, `tsc` native | paravirtual clock sources | `[7]` |
| PS/2 controller off, USB kbd/mouse instead | emulated-input fingerprint | `[7]` |
| **patched QEMU emulator** | QEMU-specific strings/behaviours | `[2]` → `/opt/AutoVirt/emulator/bin/qemu-system-x86_64` |
| **spoofed SMBIOS** (`-smbios file=…/smbios.bin`) | "QEMU"/"Bochs"/"SeaBIOS" DMI strings | `[2]`/`[3]` → `/opt/AutoVirt/firmware/smbios.bin` |
| **patched EDK2/OVMF** + real MS Secure Boot keys | OVMF vendor strings, missing SB | `[3]` → `/opt/AutoVirt/firmware/OVMF_{CODE,VARS}.fd` |
| `host-passthrough`, `check=none`, cache/maxphysaddr passthrough | CPU model mismatch | `[7]` |
| **nvme** disk with spoofed serial + 4K blocks | `QEMU HARDDISK` / virtio storage tells | `[7]` |
| `e1000e` NIC, MAC reusing the **host OUI** | virtio-net / well-known QEMU OUI | `[7]` |
| `tpm-crb` emulated TPM, S3/S4 power states | missing TPM / no sleep states | `[7]` |
| emulated TPM vendor strings (libtpms) | `"IBM"`/`"SW TPM"` give away swtpm | manual (see `~/AutoVirt/modules/README.md`) |
| real discrete GPU (passthrough) | virtual QXL/VGA adapter | `[4]`/PDS + Phase 6 |

> **Order matters.** `[7]` references `/opt/AutoVirt/emulator/bin/…` and
> `/opt/AutoVirt/firmware/…`, which are produced by `[2]` and `[3]`. **Run
> `[2]` and `[3]` before `[7]` or the deploy fails.** This is the step the old
> version of this guide missed.

---

## Phase 0 — Prerequisites (verify)
- BIOS: **VT-d = Enabled**, **IGD Multi-Monitor = Enabled** (so the iGPU drives the host while the dGPU is free).
- Booted into the desktop on the **iGPU** (monitor on the motherboard output).
- `dmesg | grep -i -e DMAR -e IOMMU` shows `IOMMU enabled`.
- Monitor: feed it BOTH the motherboard output (host/KDE) and the dGPU (the VM), then switch the monitor's input source to flip between them. A **blank dGPU port** once the GPU is bound to `vfio-pci` (Phase 4) is expected, not a fault.

## Phase 1 — Install the virt stack (AutoVirt `[1]`)
```bash
cd ~/AutoVirt && ./main.sh      # choose [1] Virtualization Setup
```
Installs `libvirt virt-manager qemu-base edk2-ovmf swtpm dnsmasq`, adds you to
`kvm`/`libvirt`/`input` groups, enables `libvirtd`, creates the NAT network.
**Log out/in** (or reboot) so the group membership applies.

## Phase 2 — Build the patched QEMU (AutoVirt `[2]`)  ← concealment core
```bash
cd ~/AutoVirt && ./main.sh      # choose [2] QEMU (Patched) Setup
```
Compiles a QEMU whose KVM signature / hypervisor tells are stripped and installs
it under **`/opt/AutoVirt/emulator/`** (the deploy step points the domain's
emulator there). Also produces the spoofed **`smbios.bin`**.

## Phase 3 — Build the patched EDK2/OVMF (AutoVirt `[3]`)  ← concealment core
```bash
cd ~/AutoVirt && ./main.sh      # choose [3] EDK2 (Patched) Setup
```
Builds OVMF with `SECURE_BOOT_ENABLE`, `SMM_REQUIRE`, `TPM2_ENABLE`, injects the
real Microsoft PK/KEK/DB Secure Boot keys, and drops
**`/opt/AutoVirt/firmware/OVMF_{CODE,VARS}.fd`** (Win11-valid firmware that
doesn't announce itself as OVMF).

## Phase 4 — Bind the dGPU to vfio-pci (PDS — UKI/rEFInd gap)
AutoVirt's `[4]` bails on a UKI+rEFInd box ("no supported bootloader"). Use PDS instead:
```bash
cd ~/PDS
source bash/arch/virtualisation.sh
vfio_gpu_ids
#   01:00.0 VGA   ... [10de:XXXX]
#   01:00.1 Audio ... [10de:YYYY]
configure_vfio_passthrough "10de:XXXX,10de:YYYY"   # GPU id + its audio fn
```
This writes `/etc/modprobe.d/vfio.conf`, adds vfio modules to the initramfs,
patches `intel_iommu=on iommu=pt vfio-pci.ids=…` into `/etc/kernel/cmdline`, and
rebuilds the UKI (`mkinitcpio -P`). Then **reboot**.

### Verify the host released the GPU
```bash
lspci -nnk -d 10de:XXXX        # Kernel driver in use: vfio-pci   <-- want this
lspci -nnk -d 10de:YYYY        # same for the audio function
dmesg | grep -i iommu          # IOMMU enabled
```
If it still says `nvidia`/`nouveau`, the bind didn't take — recheck Phase 4 and
that the host is on the iGPU. (A dark monitor on the dGPU port is normal: once
bound to `vfio-pci`, the card no longer drives a host display.)

## Phase 5 — Storage + install media
- **No `virtio-win` needed.** The deploy uses an **nvme** disk bus, which Windows
  11 install media supports natively — there is no "load viostor" step. (Add
  virtio drivers later from inside the guest only if you want the virtio NIC;
  the default `e1000e` already works.)
- **Windows 11 ISO** goes in **`~/Downloads`** — `deploy.sh` scans that directory
  and lets you pick. (It also auto-grants `libvirt-qemu` traverse access to it.)
- **Disk location:** the deploy creates a **500 GB** nvme volume in libvirt's
  **`default`** storage pool. On this box `/` is small (~32 GB), so the `default`
  pool is pointed at **`/home`** (182 GB free). PDS persists this (no more ad-hoc
  `virsh pool-define-as`):
  ```bash
  cd ~/PDS && source bash/arch/virtualisation.sh
  configure_libvirt_pool            # repoints the `default` pool -> /home/VMs
  ```
  (qcow2 is sparse — the 500 GB is a ceiling, not upfront usage.)

## Phase 6 — Deploy the concealed VM (AutoVirt `[7]`)
```bash
cd ~/AutoVirt && ./main.sh      # choose [7] Deploy Auto/Unattended XML
```
Prompts you for: **Hyper-V** (answer **n** for malware analysis — enabling it
re-exposes a hypervisor and the `hypervclock`), **evdev** (optional shared
kbd/mouse), **audio** (optional PipeWire), **RAM**, and the **ISO** to use. It
then `virt-install`s the domain `AutoVirt` with every concealment knob above,
plus a randomised MAC (host OUI) and disk serial.

> The generated domain uses `--graphics spice --video vga` so you have a console
> for the Windows install. That virtual adapter is itself a VM tell — switch it
> off once the dGPU is attached (Phase 7).

Install Windows through the SPICE console (Skip MS account: at the network step,
**Shift+F10 → `oobe\bypassnro`**), then shut the VM down.

> **Reproducible alternative (skip the interactive menu).** `[7]` is interactive,
> so it can't be replayed on a fresh box without re-prompting. PDS persists the
> resulting domain as a template — once `[2]`/`[3]` have built the emulator/firmware
> and the pool exists, define the VM in one shot:
> ```bash
> cd ~/PDS && source bash/arch/virtualisation.sh
> vfio_gpu_ids                                   # note the GPU + audio PCI addresses
> VM_ISO=~/Downloads/Win11.iso \
>   GPU_VGA="0x01 0x00 0x0" GPU_AUDIO="0x01 0x00 0x1" \
>   define_concealed_vm                          # defines from concealed-vm.xml.template
> ```
> After the VM is dialed in, snapshot it back so the template matches your box
> exactly: `export_concealed_vm` (then review `git diff` and commit). The template
> already bakes in the Phase 7.5 hardening.

## Phase 7 — Attach the dGPU + go headless (VM off)
Passing the **real** GPU removes the virtual-display tell and gives the guest a
genuine NVIDIA adapter. PDS scripts this (no hand `virsh edit`) — **VM must be
shut down first**, as it strips the SPICE console:
```bash
cd ~/PDS && source bash/arch/virtualisation.sh
attach_gpu_passthrough AutoVirt        # auto-detects the NVIDIA VGA + audio fn
```
It adds both PCI host devices with **`<rom bar='off'/>`** and removes
`<graphics>`/`<video>` so no QXL/VGA adapter remains. (Pass addresses explicitly
if auto-detect is wrong: `attach_gpu_passthrough AutoVirt 01:00.0 01:00.1`.)

`kvm.hidden.state=on` (already set by `[7]`) doubles as the classic NVIDIA
**Code 43** guard, so consumer drivers install cleanly. If Windows still flags
Code 43, add under `<features>`:
```xml
  <kvm><hidden state='on'/></kvm>
  <vendor_id state='on' value='1234567890ab'/>
```
Then: **switch the monitor's input to the dGPU**, boot the VM, install the
**NVIDIA driver** in the guest, reboot → full speed.

## Phase 8 — Verify concealment from inside the guest
Before trusting it with live samples, run a VM-detection probe **in the guest**
and confirm it reports few/no hits:
- **Pafish** — `github.com/a0rtega/pafish`
- **Al-Khaser** — `github.com/LordNoteworthy/al-khaser`

Anything they flag is a remaining tell — chase it down (common leftovers: swtpm
vendor strings → patch libtpms per `~/AutoVirt/modules/README.md`; residual SPICE
device; hostname/registry artifacts).

## Phase 9 — Keyboard & mouse for the VM
- Easiest: **USB Host Device** passthrough of a spare keyboard + mouse.
- Shared with host: **evdev** (offered by `[7]`; toggle with the chosen key combo).
- Slickest: **Looking Glass** (AutoVirt `[6]`) — but note its IVSHMEM device is a
  VM tell; weigh against concealment for true malware work.

---

## Lab hygiene (malware analysis)
- **Network:** for live detonation, isolate the guest — a host-only/closed
  network or an analysis gateway (e.g. INetSim), not the NAT uplink, unless you
  specifically need real C2 traffic and accept the risk.
- **Snapshots:** take a clean snapshot before each sample so you can roll back.
- **Host exposure:** no shared folders / clipboard / drag-drop to the host while
  a sample is live.

## Troubleshooting
| Symptom | Fix |
|---|---|
| `[7]` deploy fails on missing emulator/firmware | Run `[2]` and `[3]` first — they create `/opt/AutoVirt/{emulator,firmware}`. |
| VM won't start, "device in use" | Host driver still holds the GPU (Phase 4 failed) — confirm `vfio-pci`. |
| Black screen on the dGPU, VM "running" | Normal until the NVIDIA driver is installed in the guest; use SPICE meanwhile. |
| Windows shows GPU with Code 43 | Ensure `kvm.hidden` is on; add the `vendor_id` XML guard (Phase 7). |
| `vfio_gpu_ids` shows nothing | `lspci -nn \| grep -Ei 'vga\|3d\|audio'` and pick the dGPU + its audio fn manually. |
| Pafish/Al-Khaser still flags VM | Track each hit: swtpm vendor strings, leftover SPICE/QXL, `kvmclock`, hostname. |
| Disk volume fails to allocate | `default` pool is on small `/`; repoint it at `/home` (Phase 5). |

---

## Phase 7.5 — Audit & harden the generated domain XML (mentor review)
*(Slots in between Phase 7 and Phase 8.)* AutoVirt's `[7]` sets most concealment
knobs (verified on the reference box: `memballoon none`, `ps2 off`, `smm`, the
`ssbd` flags and topology are all already present). The CPU/feature gaps it
leaves are scripted by PDS:
```bash
cd ~/PDS && source bash/arch/virtualisation.sh
harden_concealed_vm AutoVirt    # disables vmx/svm/hypervisor, requires invtsc/topoext, pmu on
```
`virsh dumpxml AutoVirt` and confirm/add the rest below — these came out of a
peer review and are the items a default deploy most often misses:

- **`<memballoon model='none'/>`** — the virtio memory balloon is a VM tell and
  is the gap most likely present. Remove it.
- **CPU feature masking** — under `<cpu mode='host-passthrough'>` add
  `<feature policy='require' name='invtsc'/>` (defeats RDTSC-delta timing checks
  — a very common detection), `require topoext`, `disable hypervisor`
  (belt-and-braces with Hyper-V off), and `disable svm`/`vmx-*` so no
  nested-virt flags leak.
- **Plausible CPU topology + pinning** — set `<topology sockets='1' cores='8'
  threads='2'/>` (a flat or odd vCPU layout is itself a tell), then `vcpupin` /
  `emulatorpin` / `iothreadpin` + `numatune` for performance and to avoid
  scheduling jitter that timing probes notice.
- **`<pmu state='on'/>`** — expose a performance-monitoring unit; its absence is
  checkable. Confirm `<kvm><hidden state='on'/></kvm>`, `<vmport state='off'/>`,
  `<smm state='on'/>`, `<msrs unknown='fault'/>` are all present.
- **Disk *model* string, not just the serial** — verify the deploy spoofs the
  model (a real consumer SSD string) and not only the serial; pafish checks for
  `QEMU`/`QEMU HARDDISK`.
- **NIC** — `e1000e` is the default and usually works. If guest networking is
  flaky, switch the `<interface>` model to **`rtl8139`** (mentor's pick). Never
  `virtio` — that's a tell.
- **GPU passthrough `<rom bar='off'/>`** — on each GPU `<hostdev>` (also note in
  Phase 7). Suppresses a leaked option-ROM tell and often clears Code 43. If the
  NVIDIA driver then won't initialise, pass a clean dumped vBIOS via
  `<rom file='…'/>` instead.
- **Skip the VMware `hypervisor.cpuid.v0` metadata** seen in some example XMLs —
  it's VMware-schema metadata, ignored by the KVM/libvirt driver, and does
  nothing here. `disable hypervisor` + Hyper-V off is the real equivalent.

> **Headless management.** Once you strip the SPICE console (Phase 7), reach the
> host over SSH (PDS `main.sh` already enables `sshd`). Put that management path
> on a **separate host-only interface** — never the detonation network (see Lab
> hygiene).
