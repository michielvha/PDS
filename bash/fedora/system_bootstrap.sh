#!/bin/bash
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/fedora/system_bootstrap.sh) `

# Function: system_bootstrap
# Description: Main function for Fedora-based systems. This script is used to bootstrap my fedora workstations.
system_bootstrap() {
    # docker, zsh, git,...

    echo "🔧 installing packages..."

    sudo dnf update -y && sudo dnf upgrade -y
    sudo dnf install -y git zsh 

    echo "🐳 installing docker..."
    source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/fedora/software/install_docker.sh)
    install_docker
}