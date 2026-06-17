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

# Function: configure_libvirt_pool
# Description: Repoint libvirt's `default` storage pool at a roomy directory
#              (root is small on the reference box), then build/start/autostart
#              it. Replaces the ad-hoc `virsh pool-define-as` dance from the docs.
# Usage: configure_libvirt_pool [target_dir] [pool_name]   (default: /home/VMs default)
configure_libvirt_pool() {
    local target="${1:-/home/VMs}"
    local pool="${2:-default}"

    sudo mkdir -p "$target"

    if sudo virsh pool-info "$pool" >/dev/null 2>&1; then
        echo "ℹ️  pool '$pool' already defined — leaving it. Current target:"
        sudo virsh pool-dumpxml "$pool" | grep -E '<path>' || true
        echo "    (to move it: virsh pool-destroy $pool && virsh pool-undefine $pool, then re-run)"
        return 0
    fi

    echo "🔧 defining storage pool '$pool' -> $target"
    sudo virsh pool-define-as "$pool" dir --target "$target"
    sudo virsh pool-build "$pool"
    sudo virsh pool-start "$pool"
    sudo virsh pool-autostart "$pool"
    echo "✅ pool '$pool' active at $target"
}

# Function: define_concealed_vm
# Description: Define the concealed Windows VM from concealed-vm.xml.template,
#              substituting %%TOKENS%% from env vars. Refuses to define while any
#              CHANGEME_* (host-specific) placeholder remains. Makes the deploy
#              reproducible instead of clicking through AutoVirt's menu.
#              Run AutoVirt [2] and [3] first (they produce the emulator/firmware
#              this references) and configure_vfio_passthrough + a reboot.
# Usage:   VM_ISO=~/Downloads/Win11.iso GPU_VGA="0x01 0x00 0x0" GPU_AUDIO="0x01 0x00 0x1" \
#              define_concealed_vm [template_path]
# Env (all optional except the GPU addresses, which must replace CHANGEME):
#   VM_NAME(AutoVirt) VM_MEM_GIB(12) VM_VCPUS(8) VM_THREADS(2)
#   VM_DISK(/home/VMs/$VM_NAME.qcow2) VM_DISK_GIB(500)
#   VM_DISK_MODEL("Samsung SSD 870 EVO") VM_DISK_SERIAL(random) VM_MAC(random, host OUI)
#   VM_NIC(e1000e) VM_ISO(required for install)
#   OVMF_CODE/OVMF_VARS/EMULATOR/SMBIOS_BIN (default to /opt/AutoVirt/...)
#   GPU_VGA / GPU_AUDIO = "bus slot function" in 0xNN form (from vfio_gpu_ids/lspci)
define_concealed_vm() {
    local tpl="${1:-$(dirname "${BASH_SOURCE[0]}")/concealed-vm.xml.template}"
    [[ -r "$tpl" ]] || { echo "❌ template not readable: $tpl"; return 1; }

    local name="${VM_NAME:-AutoVirt}"
    local mem_kib=$(( ${VM_MEM_GIB:-12} * 1024 * 1024 ))
    local vcpus="${VM_VCPUS:-8}"
    local threads="${VM_THREADS:-2}"
    local cores=$(( vcpus / threads ))
    local disk="${VM_DISK:-/home/VMs/${name}.qcow2}"
    local disk_model="${VM_DISK_MODEL:-Samsung SSD 870 EVO}"
    # plausible-looking serials/MAC if not pinned (host OUI is better — override VM_MAC)
    local disk_serial="${VM_DISK_SERIAL:-S$(tr -dc 'A-Z0-9' </dev/urandom | head -c12)}"
    local mac="${VM_MAC:-52:54:00:$(tr -dc 'a-f0-9' </dev/urandom | head -c6 | sed 's/\(..\)/\1:/g; s/:$//')}"
    local nic="${VM_NIC:-e1000e}"
    local iso="${VM_ISO:-}"
    local ovmf_code="${OVMF_CODE:-/opt/AutoVirt/firmware/OVMF_CODE.fd}"
    local ovmf_vars="${OVMF_VARS:-/opt/AutoVirt/firmware/OVMF_VARS.fd}"
    local emulator="${EMULATOR:-/opt/AutoVirt/emulator/bin/qemu-system-x86_64}"
    local smbios="${SMBIOS_BIN:-/opt/AutoVirt/firmware/smbios.bin}"

    # create the qcow2 if missing (sparse; VM_DISK_GIB is a ceiling)
    if [[ ! -f "$disk" ]]; then
        echo "🔧 creating ${VM_DISK_GIB:-500}G qcow2 at $disk"
        sudo mkdir -p "$(dirname "$disk")"
        sudo qemu-img create -f qcow2 "$disk" "${VM_DISK_GIB:-500}G" >/dev/null
    fi

    local xml
    xml="$(sed \
        -e "s|%%VM_NAME%%|${name}|g" \
        -e "s|%%MEM_KIB%%|${mem_kib}|g" \
        -e "s|%%VCPUS%%|${vcpus}|g" \
        -e "s|%%CORES%%|${cores}|g" \
        -e "s|%%THREADS%%|${threads}|g" \
        -e "s|%%DISK_PATH%%|${disk}|g" \
        -e "s|%%DISK_MODEL%%|${disk_model}|g" \
        -e "s|%%DISK_SERIAL%%|${disk_serial}|g" \
        -e "s|%%MAC%%|${mac}|g" \
        -e "s|%%NIC_MODEL%%|${nic}|g" \
        -e "s|%%ISO_PATH%%|${iso}|g" \
        -e "s|%%OVMF_CODE%%|${ovmf_code}|g" \
        -e "s|%%OVMF_VARS%%|${ovmf_vars}|g" \
        -e "s|%%EMULATOR%%|${emulator}|g" \
        -e "s|%%SMBIOS_BIN%%|${smbios}|g" \
        "$tpl")"

    # substitute the GPU host addresses if provided ("bus slot function")
    if [[ -n "$GPU_VGA" ]]; then
        read -r gb gs gf <<<"$GPU_VGA"
        xml="${xml//CHANGEME_GPU_VGA_BUS/$gb}"; xml="${xml//CHANGEME_GPU_VGA_SLOT/$gs}"; xml="${xml//CHANGEME_GPU_VGA_FN/$gf}"
    fi
    if [[ -n "$GPU_AUDIO" ]]; then
        read -r ab as af <<<"$GPU_AUDIO"
        xml="${xml//CHANGEME_GPU_AUDIO_BUS/$ab}"; xml="${xml//CHANGEME_GPU_AUDIO_SLOT/$as}"; xml="${xml//CHANGEME_GPU_AUDIO_FN/$af}"
    fi

    if grep -q 'CHANGEME_' <<<"$xml"; then
        echo "❌ host-specific placeholders still present — set GPU_VGA/GPU_AUDIO (or edit $tpl):"
        grep -o 'CHANGEME_[A-Z_]*' <<<"$xml" | sort -u | sed 's/^/    /'
        echo "    find them with: vfio_gpu_ids ; lspci -nn | grep -i nvidia"
        echo "    e.g. GPU_VGA=\"0x01 0x00 0x0\" GPU_AUDIO=\"0x01 0x00 0x1\""
        return 1
    fi

    local tmp; tmp="$(mktemp --suffix=.xml)"
    printf '%s\n' "$xml" >"$tmp"
    echo "🔧 validating + defining domain '$name'"
    sudo virsh define "$tmp" && rm -f "$tmp"
    echo "✅ defined '$name'. Boot it with: sudo virsh start $name"
    echo "   Verify concealment in-guest with pafish / al-khaser (docs Phase 8)."
}

# Function: export_concealed_vm
# Description: Snapshot a working domain back into the template so PDS reflects
#              exactly what runs on your box. Dumps the live XML, strips the
#              host-instance UUID so it can be redefined cleanly, and writes it
#              next to the script (overwriting the template) — review the diff
#              before committing.
# Usage: export_concealed_vm [domain_name] [out_path]
export_concealed_vm() {
    local name="${1:-AutoVirt}"
    local out="${2:-$(dirname "${BASH_SOURCE[0]}")/concealed-vm.xml.template}"
    sudo virsh dumpxml --migratable "$name" \
        | grep -vE '^\s*<uuid>' \
        > "$out" || { echo "❌ dumpxml failed for '$name'"; return 1; }
    echo "✅ wrote $out — review 'git diff' (paths/MAC/PCI are now host-specific) before committing."
}

# Function: harden_concealed_vm
# Description: Apply the anti-VM-detection CPU/feature hardening (docs Phase 7.5)
#              to an existing domain, idempotently and reproducibly — replaces a
#              one-off `virsh edit`. Hides nested-virt (vmx/svm) + the hypervisor
#              bit, forces invariant-TSC / topoext, exposes a PMU, and normalises
#              the vCPU topology to a plausible, non-oversubscribed layout (a flat
#              or >host vCPU count is both a perf bug and a tell). Edits the
#              persistent config (takes effect next boot); safe on a running VM.
# Usage: harden_concealed_vm [domain_name]            (default: AutoVirt)
#        VM_VCPUS=24 harden_concealed_vm              (override the vCPU count)
# Note:  virt-xml REPLACES the <cpu> feature list, so the FULL desired set is
#        passed below — adding a feature here means adding it to this list.
harden_concealed_vm() {
    local name="${1:-AutoVirt}"
    command -v virt-xml >/dev/null 2>&1 || { echo "❌ virt-xml not found (pkg: virt-install)"; return 1; }
    sudo virsh -c qemu:///system dominfo "$name" >/dev/null 2>&1 \
        || { echo "❌ domain '$name' not found on qemu:///system"; return 1; }

    local cpuspec="host-passthrough,check=none,migratable=off"
    cpuspec+=",disable=vmx,disable=svm,disable=hypervisor"       # no nested-virt / hypervisor-present tell
    cpuspec+=",disable=ssbd,disable=amd-ssbd,disable=virt-ssbd"  # keep AutoVirt's spectre-flag masking
    cpuspec+=",require=invtsc,require=topoext"                   # invariant TSC defeats RDTSC-delta probes

    echo "🔧 hardening CPU features on '$name'"
    sudo virt-xml "$name" --edit --cpu "$cpuspec"            || return 1
    echo "🔧 exposing a PMU"
    sudo virt-xml "$name" --edit --features pmu.state=on     || return 1

    # Normalise vCPU topology: 2 threads/core, leave host headroom (AutoVirt
    # naively sets cores=<host cores>*threads, which oversubscribes a hybrid CPU).
    local threads=2 host_cpus vcpus cores
    host_cpus=$(nproc)
    vcpus="${VM_VCPUS:-16}"
    if (( vcpus > host_cpus )); then
        echo "⚠️  VM_VCPUS=$vcpus exceeds host's $host_cpus logical CPUs — capping at $(( host_cpus - 4 ))"
        vcpus=$(( host_cpus - 4 ))
    fi
    (( vcpus % threads )) && vcpus=$(( vcpus - 1 ))             # keep it even for 2 threads/core
    cores=$(( vcpus / threads ))
    echo "🔧 normalising vCPU topology -> ${vcpus} vCPU (1 socket / ${cores} cores / ${threads} threads)"
    sudo virt-xml "$name" --edit --vcpus "${vcpus},sockets=1,cores=${cores},threads=${threads}" || return 1

    echo "✅ hardened '$name' — applies on next boot. Verify:"
    echo "    sudo virsh -c qemu:///system dumpxml $name | sed -n '/<cpu /,/<\\/cpu>/p'"
}

# Function: attach_gpu_passthrough
# Description: Phase 7 — attach the real dGPU (VGA + its audio fn) with rom bar
#              off and strip the virtual display, so the guest gets a genuine
#              NVIDIA adapter and the QXL/VGA tell is gone. Reproducible
#              replacement for the manual `virsh edit`. RUN ONLY AFTER Windows is
#              installed and the VM is shut down — it removes the SPICE console.
# Usage: attach_gpu_passthrough [domain] [vga_addr] [audio_addr]
#        addresses default to the NVIDIA VGA + audio fn from lspci (e.g. 01:00.0)
attach_gpu_passthrough() {
    local name="${1:-AutoVirt}" vga="${2:-}" audio="${3:-}"
    command -v virt-xml >/dev/null 2>&1 || { echo "❌ virt-xml not found (pkg: virt-install)"; return 1; }

    if [[ -z "$vga" ]]; then
        vga=$(lspci -nn | grep -Ei 'vga|3d' | grep -i nvidia | head -1 | awk '{print $1}')
        audio=$(lspci -nn | grep -Ei 'audio'  | grep -i nvidia | head -1 | awk '{print $1}')
    fi
    [[ -z "$vga" ]] && { echo "❌ no NVIDIA GPU found — pass it: attach_gpu_passthrough $name 01:00.0 01:00.1"; return 1; }

    local state; state=$(sudo virsh -c qemu:///system domstate "$name" 2>/dev/null)
    [[ "$state" == "shut off" ]] \
        || { echo "❌ '$name' is '${state:-unknown}' — shut it down first (this removes the display)."; return 1; }

    echo "🔧 attaching GPU $vga${audio:+ + $audio} to '$name' (rom bar off) and removing virtual display"
    sudo virt-xml "$name" --add-device --hostdev "${vga},rom.bar=off"   || return 1
    [[ -n "$audio" ]] && { sudo virt-xml "$name" --add-device --hostdev "${audio},rom.bar=off" || return 1; }
    sudo virt-xml "$name" --remove-device --graphics all 2>/dev/null
    sudo virt-xml "$name" --remove-device --video all    2>/dev/null

    echo "✅ GPU attached. Switch the monitor input to the dGPU, boot, install the NVIDIA driver."
    echo "   Code 43? kvm hidden is already on; add a <vendor_id> guard (docs Phase 7)."
}
