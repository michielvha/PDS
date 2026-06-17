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
