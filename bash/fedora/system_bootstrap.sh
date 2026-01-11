#!/bin/bash
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/fedora/system_bootstrap.sh) `

# Function: system_bootstrap
# Description: Main function for Fedora-based systems. This script is used to bootstrap my fedora workstations.
system_bootstrap() {
    # docker, zsh, git,...

    echo "🔧 installing packages..."

    sudo dnf update -y && sudo dnf upgrade -y
    sudo dnf install -y fastfetch yq bat btop git zsh gh make @virtualization bridge-utils dnsmasq # qemu-system-aarch64 

    sudo systemctl enable --now libvirtd
    sudo usermod -aG libvirt $USER    

    echo "🐳 installing docker..."
    source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/fedora/software/install_docker.sh)
    install_docker

    # Custom prompt with blue username and path, purple hostname
    echo "PS1='\[\033[0;34m\]\u@\[\033[0;35m\]\h:\[\033[0;34m\]\w\[\033[0m\]\$ '" > ~/.bashrc
}
