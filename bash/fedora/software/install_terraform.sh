#!/bin/bash
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/fedora/software/install_terraform.sh) `

# Function: install_terraform
# Description: Installs and configures terraform on Fedora-based systems
install_terraform() {

    echo "install terraform"
    sudo dnf install -y dnf-plugins-core
    sudo dnf config-manager addrepo --from-repofile=https://rpm.releases.hashicorp.com/fedora/hashicorp.repo
    sudo dnf -y install terraform
}
