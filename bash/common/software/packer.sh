#!/bin/bash
# Function: install_packer
# Description: Installs HashiCorp's Packer and configures the system as a Packer build host.
# Usage: install_packer
# Arguments: none
# Returns:
#   0 - Success
#   1 - Failure (e.g., unsupported architecture, missing dependencies, or installation issues)

# install hashicorps packer to create a packer build host
install_packer () {
    # Add HashiCorp GPG key and repository
    wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
    
    # Install Packer and required QEMU packages
    sudo apt update
    sudo apt install -y packer
    
    # Install architecture-specific dependencies
    if [ "$(dpkg --print-architecture)" = "amd64" ]; then
        # x86 (amd64) specific packages
        sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virtinst virt-manager genisoimage guestfs-tools
    else
        # ARM64 specific packages
        sudo apt install -y qemu-system-arm qemu-system-aarch64 qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virtinst virt-manager genisoimage guestfs-tools
    fi
    
    # Install QEMU plugin for Packer
    sudo packer plugins install github.com/hashicorp/qemu
}
