#!/bin/bash
# PDS HashiCorp Tools Functions
# This library contains functions for installing HashiCorp products

# Function: verify_hashicorp_gpg_key
# Description: Downloads and verifies the HashiCorp GPG signing key
verify_hashicorp_gpg_key() {
    local keyring_path="/usr/share/keyrings/hashicorp-archive-keyring.gpg"
    
    echo "🔑 Downloading and installing HashiCorp GPG key..."
    wget -O- https://apt.releases.hashicorp.com/gpg | \
    gpg --dearmor | \
    sudo tee "$keyring_path" > /dev/null

    # Extract fingerprint from the installed key
    echo "🔍 Extracting current key fingerprint..."
    local current_fingerprint
    current_fingerprint=$(gpg --no-default-keyring \
        --keyring "$keyring_path" \
        --list-keys --with-fingerprint --with-colons | \
        grep "^fpr" | head -1 | cut -d: -f10)
    
    # Fetch expected fingerprint from HashiCorp's website
    echo "🌐 Fetching expected fingerprint from HashiCorp's website..."
    local expected_fingerprint=""
    local hashicorp_security_page
    hashicorp_security_page=$(wget -q -O - "https://www.hashicorp.com/en/trust/security" 2>/dev/null || true)
    
    if [ -n "$hashicorp_security_page" ]; then
        expected_fingerprint=$(echo "$hashicorp_security_page" | 
                              grep -A 3 "apt.releases.hashicorp.com/gpg" | 
                              grep -o "[0-9A-F]\{4\} [0-9A-F]\{4\} [0-9A-F]\{4\} [0-9A-F]\{4\} [0-9A-F]\{4\} [0-9A-F]\{4\} [0-9A-F]\{4\} [0-9A-F]\{4\} [0-9A-F]\{4\} [0-9A-F]\{4\}" | 
                              head -1 | 
                              tr -d " ")
    fi
    
    # If we couldn't fetch the fingerprint, use a known good value as fallback
    if [ -z "$expected_fingerprint" ]; then
        echo "⚠️ Could not fetch fingerprint from website, using fallback."
        expected_fingerprint="798AEC654E5C15428C8E42EEAA16FCBCA621E701"
    fi
    
    echo "Current key fingerprint: $current_fingerprint"
    echo "Expected fingerprint:    $expected_fingerprint"
    
    # Check if the fingerprint matches the expected one
    if [ -n "$current_fingerprint" ] && [ "$current_fingerprint" = "$expected_fingerprint" ]; then
        echo "✅ GPG key verified successfully!"
        return 0
    else
        echo "❌ GPG key verification failed!"
        if [ -z "$current_fingerprint" ]; then
            echo "⚠️ Could not determine the current key fingerprint."
        else
            echo "⚠️ Expected: $expected_fingerprint" 
            echo "⚠️ Found:    $current_fingerprint"
        fi
        echo "⚠️ For security reasons, the installation has been aborted."
        echo "⚠️ Please verify manually at https://www.hashicorp.com/security"
        return 1
    fi
}

# Function: add_hashicorp_repository
# Description: Adds the HashiCorp apt repository to the system's package sources
add_hashicorp_repository() {
    echo "📦 Adding HashiCorp repository..."
    
    # Add the official HashiCorp repository to the system
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
    https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
    sudo tee /etc/apt/sources.list.d/hashicorp.list

    # Update package lists
    sudo apt-get update
}

# Function: install_hashicorp_product
# Description: Installs a HashiCorp product after verifying the GPG key and adding the repository
# Usage: install_hashicorp_product "terraform" or install_hashicorp_product "terraform" "1.5.0"
# Parameters:
#   - $1: Product name (e.g., terraform, vault, consul, nomad, packer)
#   - $2: Optional specific version to install (e.g., "1.5.0")
install_hashicorp_product() {
    local product_name="$1"
    local specific_version="$2"
    
    if [ -z "$product_name" ]; then
        echo "❌ Error: No product name provided"
        echo "Usage: install_hashicorp_product <product_name> [version]"
        echo "Available products: terraform, vault, consul, nomad, packer"
        return 1
    fi
    
    echo "🔄 Installing HashiCorp $product_name..."
    
    # Install dependencies
    sudo apt-get update && sudo apt-get install -y gnupg software-properties-common curl lsb-release
    
    # Verify HashiCorp GPG key
    verify_hashicorp_gpg_key || return 1
    
    # Add HashiCorp repository
    add_hashicorp_repository
    
    # Install the product with specific version if provided
    echo "📥 Installing $product_name..."
    if [ -n "$specific_version" ]; then
        echo "   Using specific version: $specific_version"
        sudo apt-get install -y "${product_name}=${specific_version}"
    else
        sudo apt-get install -y "$product_name"
    fi
    
    # Verify installation
    if command -v "$product_name" &> /dev/null; then
        local version_output
        version_output=$("$product_name" --version 2>/dev/null | head -n 1 || echo "Version info not available")
        echo "✅ $product_name installed successfully: $version_output"
        return 0
    else
        echo "❌ $product_name installation failed!"
        return 1
    fi
}

# Function: install_terraform
# Description: Installs HashiCorp Terraform
install_terraform() {
    install_hashicorp_product "terraform" "$1"
}

# Function: install_vault
# Description: Installs HashiCorp Vault
install_vault() {
    install_hashicorp_product "vault" "$1"
}

# Function: install_consul
# Description: Installs HashiCorp Consul
install_consul() {
    install_hashicorp_product "consul" "$1"
}

# Function: install_nomad
# Description: Installs HashiCorp Nomad
install_nomad() {
    install_hashicorp_product "nomad" "$1"
}

# Function: install_packer
# Description: Installs HashiCorp Packer and configures the system as a Packer build host
install_packer() {
    echo "📦 Installing HashiCorp Packer..."
    
    # Use the generic HashiCorp installer
    install_hashicorp_product "packer" "$1" || return 1
    
    echo "🔧 Configuring Packer build environment..."
    
    # Install architecture-specific dependencies
    if [ "$(dpkg --print-architecture)" = "amd64" ]; then
        # x86 (amd64) specific packages
        echo "Installing x86_64 virtualization packages..."
        sudo apt-get install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virtinst virt-manager genisoimage guestfs-tools
    else
        # ARM64 specific packages
        echo "Installing ARM64 virtualization packages..."
        sudo apt-get install -y qemu-system-arm qemu-system-aarch64 qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virtinst virt-manager genisoimage guestfs-tools
    fi

    # Install QEMU plugin for Packer
    echo "📦 Installing Packer QEMU plugin..."
    packer plugins install github.com/hashicorp/qemu || {
        echo "⚠️ Failed to install QEMU plugin automatically. You may need to run this manually:"
        echo "    packer plugins install github.com/hashicorp/qemu"
    }
    
    # Add user to libvirt group if it exists
    if getent group libvirt > /dev/null 2>&1; then
        sudo usermod -aG libvirt "$USER"
        echo "✅ Added $USER to libvirt group"
        echo "📝 Note: You may need to log out and back in for group membership to take effect"
    fi
    
    echo "✅ Packer installation and configuration complete!"
}
