# Windows VM + GPU passthrough (UKI / rEFInd, no GRUB)

Reference setup this was written for: **Intel 14700K + RTX 4070**, Arch + KDE,
booting a **Unified Kernel Image via rEFInd** (no GRUB), host desktop on the
**Intel iGPU**, the dGPU (4070) reserved for the VM.

> Why this doc exists: AutoVirt's `vfio.sh` only knows GRUB / systemd-boot /
> Limine and **exits** on a UKI+rEFInd box. PDS's `configure_vfio_passthrough`
> (in `bash/arch/virtualisation.sh`) covers that gap by patching
> `/etc/kernel/cmdline` and rebuilding the UKI.

Monitor: feed it BOTH the motherboard output (host/KDE) and the dGPU (the VM),
then switch the monitor's input source to flip between them.

---

## Phase 0 — Prerequisites (verify)
- BIOS: **VT-d = Enabled**, **IGD Multi-Monitor = Enabled** (MSI: OC → CPU Features, and Advanced → Integrated Graphics Configuration).
- Booted into the desktop on the **iGPU** (monitor on the motherboard input).
- `dmesg | grep -i -e DMAR -e IOMMU` shows `IOMMU enabled`.

## Phase 1 — Install the virt stack (AutoVirt option 1)
```bash
cd ~/AutoVirt && ./main.sh      # choose [1] Virtualization Setup
```
Installs `libvirt virt-manager qemu-base edk2-ovmf swtpm dnsmasq`, adds you to
`kvm`/`libvirt`/`input` groups, enables `libvirtd`, creates a NAT network.
**Log out/in** (or reboot) so the group membership applies.

## Phase 2 — Bind the dGPU to vfio-pci (PDS, replaces AutoVirt option 4)
```bash
cd ~/PDS
source bash/arch/virtualisation.sh
vfio_gpu_ids
#   01:00.0 VGA ... [10de:XXXX]
#   01:00.1 Audio ... [10de:YYYY]
configure_vfio_passthrough "10de:XXXX,10de:YYYY"   # GPU id + audio id
```
Then **reboot**.

## Phase 3 — Verify the host released the GPU
```bash
lspci -nnk -d 10de:XXXX        # Kernel driver in use: vfio-pci   <-- want this
dmesg | grep -i iommu          # IOMMU enabled
```
If it still says `nvidia`/`nouveau`, the bind didn't take — recheck Phase 2 and
that the host is on the iGPU (monitor on the motherboard input).

## Phase 4 — Get the install media
- **Windows 11 ISO** — from Microsoft.
- **virtio-win drivers ISO**:
  ```bash
  yay -S virtio-win        # AUR
  # or: https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso
  ```
  Put both where libvirt can read them (e.g. `/var/lib/libvirt/images/`).

## Phase 5 — Create the VM (virt-manager)
New VM → Local install media → **Windows 11 ISO** → **✅ Customize before install**:
- **Chipset = Q35**, **Firmware = UEFI** (an `OVMF_CODE…secboot…` entry for Win11; plain OVMF also works).
- **CPUs → Model = `host-passthrough`**, 8–16 vCPUs; **RAM 16–32 GB**.
- **Add Hardware → TPM → Emulated, Version 2.0** (Win11 requires it; backed by `swtpm`).
- **Disk bus = VirtIO** (fast) — or SATA for simplicity (no driver needed at install).
- **NIC → device model = virtio**.
- **Add Hardware → Storage → CDROM** → attach the **virtio-win ISO** (2nd CD).
- Leave the default **Spice + QXL/Virtio video** for now (your install screen on the host).
- **Begin Installation.**

## Phase 6 — Install Windows (host-side Spice window)
- If the installer shows **no disk** (VirtIO): **Load driver** → virtio-win CD → `amd64\w11\` → load **viostor/vioscsi**. Disk appears.
- Finish install. (Skip MS account: at the network step, Shift+F10 → `oobe\bypassnro`.)
- On the desktop, run **`virtio-win-guest-tools.exe`** from the CD (all virtio drivers).
- **Shut the VM down.**

## Phase 7 — Attach the dGPU (VM off)
- **Add Hardware → PCI Host Device → 01:00.0** (GPU **VGA**).
- **Add Hardware → PCI Host Device → 01:00.1** (GPU **Audio**).

Optional NVIDIA "Error 43" guard — usually NOT needed on a 40-series with current
drivers, but if Windows flags Code 43, `virsh edit <vm>` and under `<features>`:
```xml
  <kvm><hidden state='on'/></kvm>
  <vendor_id state='on' value='1234567890ab'/>
```
(and ensure `<hyperv>` has a `<vendor_id state='on' value='...'/>`).

## Phase 8 — Boot + install the NVIDIA driver
- **Switch the monitor's input to the dGPU.** Start the VM.
- Windows boots; the GPU drives that monitor (basic res at first).
- Install the **GeForce/NVIDIA driver** in the guest → reboot the VM → full speed.

## Phase 9 — Keyboard & mouse for the VM
- Easiest: **Add Hardware → USB Host Device** → pass a spare USB keyboard + mouse.
- Shared with host: **evdev passthrough** (`<input type='evdev'>` for the
  `/dev/input/by-id/...-kbd` and `...-mouse`; toggle with both Ctrl keys).
- Slickest: **Looking Glass** (VM in a window on the host desktop) — set up later.

---

## Optional, later
- **Performance:** CPU pinning (pin guest vCPUs to physical cores + isolate),
  hugepages, CPU feature tuning.
- **Anti-detection** (only if a game's kernel anti-cheat blocks VMs): AutoVirt
  options 2 (patched QEMU) + 3 (patched EDK2) + the spoofing in option 7.

## Troubleshooting
| Symptom | Fix |
|---|---|
| VM won't start, "device in use" | Host driver still holds the GPU (Phase 3 failed) — confirm `vfio-pci`. |
| Black screen on the dGPU, VM "running" | Normal until the NVIDIA driver is installed in the guest; use Spice meanwhile. |
| Installer shows no disk | Load `viostor` from the virtio-win CD (Phase 6). |
| Windows shows GPU with Code 43 | Apply the XML guard in Phase 7. |
| `vfio_gpu_ids` shows nothing | `lspci -nn | grep -Ei 'vga|3d|audio'` and pick the dGPU + its audio fn manually. |
