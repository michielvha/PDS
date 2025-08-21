#!/bin/bash
# shellcheck disable=SC2016
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/common/software/hashicorp.sh) `

# Function: detect_platform
# Description: Detects the Linux distribution and architecture
detect_platform() {
    local -n platform_ref=$1
    
    echo "🔍 Detecting Linux distribution and architecture..."
    
    # Detect distribution
    local distro=""
    local distro_version=""
    
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        case "$ID" in
            ubuntu|debian|zorin)
                distro="debian"
                distro_version="$VERSION_CODENAME"
                echo "📋 Detected: $PRETTY_NAME (Debian-based)"
                ;;
            centos|rhel|rocky|almalinux)
                distro="rhel"
                distro_version="$VERSION_ID"
                echo "📋 Detected: $PRETTY_NAME (RHEL-based)"
                ;;
            fedora)
                distro="fedora"
                distro_version="$VERSION_ID"
                echo "📋 Detected: $PRETTY_NAME (Fedora)"
                ;;
            amzn)
                distro="amazon"
                distro_version="$VERSION_ID"
                echo "📋 Detected: $PRETTY_NAME (Amazon Linux)"
                ;;
            *)
                echo "❌ Unsupported distribution: $PRETTY_NAME"
                return 1
                ;;
        esac
    else
        echo "❌ Cannot detect Linux distribution"
        return 1
    fi
    
    # Detect architecture
    local arch
    arch=$(dpkg --print-architecture 2>/dev/null || uname -m)
    echo "🏗️  Architecture: $arch"
    
    # Return platform info via nameref
    platform_ref[distro]="$distro"
    platform_ref[distro_version]="$distro_version"
    platform_ref[arch]="$arch"
}

# Function: install_packer_dependencies
# Description: Installs Packer dependencies including QEMU/KVM packages
install_packer_dependencies() {
    local -A platform=()
    platform[distro]="$1"
    platform[arch]="$2"
    
    echo "� Installing Packer dependencies for ${platform[distro]} on ${platform[arch]}..."
    
    case "${platform[distro]}" in
        debian)
            echo "🔧 Installing QEMU/KVM dependencies via APT..."
            # Install architecture-specific dependencies
            if [ "${platform[arch]}" = "amd64" ]; then
                # x86 (amd64) specific packages
                sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virtinst virt-manager genisoimage guestfs-tools
            else
                # ARM64 specific packages
                sudo apt install -y qemu-system-arm qemu-system-aarch64 qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virtinst virt-manager genisoimage guestfs-tools
            fi
            ;;
        rhel)
            echo "🔧 Installing QEMU/KVM dependencies via YUM..."
            if [ "${platform[arch]}" = "x86_64" ]; then
                # x86_64 specific packages
                sudo yum install -y qemu-kvm libvirt virt-install bridge-utils virt-manager genisoimage libguestfs-tools
            else
                # ARM64 specific packages  
                sudo yum install -y qemu-system-aarch64 qemu-kvm libvirt virt-install bridge-utils virt-manager genisoimage libguestfs-tools
            fi
            ;;
        fedora)
            echo "🔧 Installing QEMU/KVM dependencies via DNF..."
            if [ "${platform[arch]}" = "x86_64" ]; then
                # x86_64 specific packages
                sudo dnf install -y qemu-kvm libvirt virt-install bridge-utils virt-manager genisoimage libguestfs-tools
            else
                # ARM64 specific packages
                sudo dnf install -y qemu-system-aarch64 qemu-kvm libvirt virt-install bridge-utils virt-manager genisoimage libguestfs-tools
            fi
            ;;
        amazon)
            echo "🔧 Installing QEMU/KVM dependencies via YUM..."
            if [ "${platform[arch]}" = "x86_64" ]; then
                # x86_64 specific packages
                sudo yum install -y qemu-kvm libvirt virt-install bridge-utils genisoimage
            else
                # ARM64 specific packages
                sudo yum install -y qemu-system-aarch64 qemu-kvm libvirt virt-install bridge-utils genisoimage
            fi
            ;;
        *)
            echo "⚠️  Dependency installation not implemented for: ${platform[distro]}"
            ;;
    esac
}

# Function: install_packer_package
# Description: Installs HashiCorp Packer package
install_packer_package() {
    local -A platform=()
    platform[distro]="$1"
    platform[distro_version]="$2"
    
    echo "�🚀 Installing HashiCorp Packer for ${platform[distro]}..."
    
    # Install based on detected distribution
    case "${platform[distro]}" in
        debian)
            echo "📦 Installing via APT (Debian/Ubuntu)..."
            # Add HashiCorp GPG key to keyring
            curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
            # Add HashiCorp repository
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
            sudo apt-get update && sudo apt-get install -y packer
            ;;
        rhel)
            echo "📦 Installing via YUM (RHEL/CentOS/Rocky/AlmaLinux)..."
            sudo yum install -y yum-utils
            sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
            sudo yum -y install packer
            ;;
        fedora)
            echo "📦 Installing via DNF (Fedora)..."
            sudo dnf install -y dnf-plugins-core
            sudo dnf config-manager addrepo --from-repofile=https://rpm.releases.hashicorp.com/fedora/hashicorp.repo
            sudo dnf -y install packer
            ;;
        amazon)
            echo "📦 Installing via YUM (Amazon Linux)..."
            sudo yum install -y yum-utils
            sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/Amazon/amazon-linux.repo
            sudo yum -y install packer
            ;;
        *)
            echo "❌ Installation method not implemented for: ${platform[distro]}"
            return 1
            ;;
    esac
}

# Function: install_packer
# Description: Main function to install HashiCorp Packer and its dependencies. This function is completely platform agnostic and works on any of the officially supported Linux distributions.
# Reference: https://developer.hashicorp.com/packer/tutorials/docker-get-started/get-started-install-cli#installing-packer
install_packer() {
    local -A platform=()
    
    # Detect platform
    if ! detect_platform platform; then
        return 1
    fi
    
    # Install dependencies
    install_packer_dependencies "${platform[distro]}" "${platform[arch]}"
    
    # Install Packer
    if ! install_packer_package "${platform[distro]}" "${platform[distro_version]}"; then
        return 1
    fi
    
    # Verify installation
    if command -v packer >/dev/null 2>&1; then
        local packer_version
        packer_version=$(packer version | head -n1)
        echo "✅ HashiCorp Packer installation complete!"
        echo "📌 Installed version: $packer_version"
    else
        echo "❌ Packer installation failed or not found in PATH"
        return 1
    fi
}

