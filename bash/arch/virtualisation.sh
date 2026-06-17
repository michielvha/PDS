#!/bin/bash
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/arch/virtualisation.sh) `

# Function: setup_autovirt
# Description: Clone (or fast-forward) Scrut1ny/AutoVirt and launch its installer
#              to configure QEMU/KVM/libvirt + VFIO GPU passthrough. Arch is
#              AutoVirt's first-class path, so no EXPERIMENTAL flag is required.
#              Usage: setup_autovirt [target_dir]   (default: ~/AutoVirt)
setup_autovirt() {
    local dir="${1:-$HOME/AutoVirt}"

    command -v git >/dev/null 2>&1 || sudo pacman -S --needed --noconfirm git

    if [[ -d "$dir/.git" ]]; then
        echo "[setup_autovirt] updating $dir"
        git -C "$dir" pull --ff-only
    else
        echo "[setup_autovirt] cloning AutoVirt into $dir"
        git clone --single-branch --depth=1 https://github.com/Scrut1ny/AutoVirt "$dir"
    fi

    # run the interactive installer from its own dir without leaking cwd
    ( cd "$dir" && ./main.sh )
}

# Function: vfio_gpu_ids
# Description: Print PCI vendor:device IDs of discrete GPUs and their companion
#              audio function — feed BOTH into configure_vfio_passthrough.
vfio_gpu_ids() {
    lspci -nn | grep -Ei 'vga|3d|audio' | grep -Ei 'nvidia|\[1002:'
}

# Function: configure_vfio_passthrough
# Description: Kernel-side GPU passthrough for Arch systems that boot a Unified
#              Kernel Image via rEFInd / EFISTUB (NO GRUB — exactly where
#              AutoVirt's vfio.sh bails with "no supported bootloader detected").
#              Binds the given PCI IDs to vfio-pci and injects the IOMMU params
#              into the UKI cmdline (/etc/kernel/cmdline), then rebuilds the UKI.
# Usage: configure_vfio_passthrough "10de:2786,10de:22bc"
#        (find the ids with: vfio_gpu_ids  — include the GPU *and* its audio fn)
configure_vfio_passthrough() {
    local ids="$1"
    local cmdline_file="/etc/kernel/cmdline"
    local modprobe_file="/etc/modprobe.d/vfio.conf"
    local mkinitcpio_conf="/etc/mkinitcpio.conf"

    [[ -z "$ids" ]] && { echo "Usage: configure_vfio_passthrough <vendor:dev[,vendor:dev...]>  (run 'vfio_gpu_ids' to find them)"; return 1; }

    # IOMMU enable flag depends on CPU vendor
    local iommu="amd_iommu=on"
    grep -q GenuineIntel /proc/cpuinfo && iommu="intel_iommu=on"

    # 1) Bind the GPU to vfio-pci ahead of any real driver
    echo "🔧 $modprobe_file -> bind $ids to vfio-pci"
    printf 'options vfio-pci ids=%s disable_vga=1\nsoftdep nvidia pre: vfio-pci\nsoftdep nouveau pre: vfio-pci\nsoftdep amdgpu pre: vfio-pci\n' "$ids" \
        | sudo tee "$modprobe_file" >/dev/null

    # 2) Ensure vfio modules are in the initramfs so they claim the card early
    if ! grep -q 'vfio_pci' "$mkinitcpio_conf"; then
        echo "🔧 adding vfio modules to $mkinitcpio_conf"
        sudo sed -i -E 's/^MODULES=\((.*)\)/MODULES=(vfio_pci vfio vfio_iommu_type1 \1)/' "$mkinitcpio_conf"
    fi

    # 3) Inject IOMMU + vfio params into the UKI cmdline (idempotent: strip old, re-add)
    if [[ -f "$cmdline_file" ]]; then
        echo "🔧 patching UKI cmdline: $cmdline_file"
        local current cleaned
        current="$(tr '\n' ' ' < "$cmdline_file")"
        cleaned="$(echo "$current" | sed -E 's/(intel_iommu=[^ ]*|amd_iommu=[^ ]*|iommu=[^ ]*|vfio-pci\.ids=[^ ]*)//g; s/  +/ /g; s/^ //; s/ $//')"
        echo "${cleaned} ${iommu} iommu=pt vfio-pci.ids=${ids}" | sudo tee "$cmdline_file" >/dev/null
    else
        echo "⚠️  $cmdline_file not found (not a mkinitcpio UKI setup). Add manually to your boot:"
        echo "    ${iommu} iommu=pt vfio-pci.ids=${ids}"
        return 1
    fi

    # 4) Rebuild the UKI + initramfs
    echo "🔧 rebuilding initramfs / UKI (mkinitcpio -P)"
    sudo mkinitcpio -P

    echo "✅ Done. Reboot, then confirm the host released the GPU:"
    echo "    lspci -nnk | grep -A3 -Ei 'nvidia|vga'   # want -> Kernel driver in use: vfio-pci"
}
