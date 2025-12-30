#!/bin/bash
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/common/software/install_cloudflared.sh) `

# Source utility functions
# shellcheck source=/dev/null
source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/common/utils/detect_distro.sh)

# Function: install_cloudflared
# Description: Installs Cloudflare Tunnel (cloudflared) on various Linux distributions
# Reference: https://github.com/cloudflare/cloudflared
install_cloudflared() {
    local os_release
    local arch

    # Check if cloudflared is already installed
    if command -v cloudflared &> /dev/null; then
        echo "cloudflared is already installed."
        cloudflared --version
        return
    fi

    echo "=== Cloudflare Tunnel (cloudflared) Installer ==="
    echo ""

    # Detect architecture
    arch=$(uname -m)
    case "$arch" in
        x86_64)
            arch="amd64"
            ;;
        aarch64|arm64)
            arch="arm64"
            ;;
        armv7l)
            arch="arm"
            ;;
        i386|i686)
            arch="386"
            ;;
        *)
            echo "❌ Unsupported architecture: $arch"
            return 1
            ;;
    esac

    # Detect OS
    os_release=$(get_os_release)

    echo "Detected: linux-$arch"
    echo "Distribution: $os_release"
    echo ""

    # Install based on distribution
    case "$os_release" in
        debian|ubuntu|linuxmint|pop)
            echo "Installing via apt..."
            local deb_file="cloudflared-linux-$arch.deb"
            wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/"$deb_file"
            sudo dpkg -i "$deb_file"
            rm "$deb_file"
            ;;

        fedora|rhel|centos|rocky|almalinux)
            echo "Installing via official Cloudflare repository..."
            # Add Cloudflare repository
            if command -v dnf &> /dev/null; then
                echo "Adding Cloudflare repository (stable)..."
                curl -fsSL https://pkg.cloudflare.com/cloudflared.repo | sudo tee /etc/yum.repos.d/cloudflared.repo > /dev/null
                echo "Updating repositories..."
                sudo dnf update -y --quiet
                echo "Installing cloudflared..."
                sudo dnf install -y cloudflared
            elif command -v yum &> /dev/null; then
                echo "Adding Cloudflare repository (stable)..."
                curl -fsSL https://pkg.cloudflare.com/cloudflared.repo | sudo tee /etc/yum.repos.d/cloudflared.repo > /dev/null
                echo "Updating repositories..."
                sudo yum update -y --quiet
                echo "Installing cloudflared..."
                sudo yum install -y cloudflared
            else
                echo "No dnf/yum found, installing binary directly..."
                install_cloudflared_binary "$arch"
            fi
            ;;

        arch|manjaro|endeavouros)
            echo "Installing via AUR..."
            if command -v yay &> /dev/null; then
                yay -S --noconfirm cloudflared
            elif command -v paru &> /dev/null; then
                paru -S --noconfirm cloudflared
            else
                echo "No AUR helper found, installing binary directly..."
                install_cloudflared_binary "$arch"
            fi
            ;;

        opensuse*|sles)
            echo "Installing via zypper..."
            local rpm_file="cloudflared-linux-$arch.rpm"
            wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/"$rpm_file"
            sudo zypper install -y "$rpm_file"
            rm "$rpm_file"
            ;;

        *)
            echo "Unknown distro, installing binary directly..."
            install_cloudflared_binary "$arch"
            ;;
    esac

    # Verify installation
    if command -v cloudflared &> /dev/null; then
        local version
        version=$(cloudflared --version)
        echo ""
        echo "✅ Successfully installed: $version"
        echo ""
        echo "📚 Next steps:"
        echo "  1. Authenticate: cloudflared tunnel login"
        echo "  2. Create tunnel: cloudflared tunnel create <name>"
        echo "  3. Create DNS route: cloudflared tunnel route dns <name> <hostname>"
        echo "     (Or create CNAME manually in Cloudflare dashboard)"
        echo "  4. Create config file and deploy:"
        echo "     source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/common/cloud/cloudflare.sh)"
        echo "     deploy_cloudflare_tunnel_config ./config.yml <name> --enable-service"
        echo ""
        echo "💡 For detailed instructions, see the documentation in cloudflare.sh"
        echo "💡 Quick test (without tunnel): cloudflared tunnel --url http://localhost:8080"
    else
        echo "❌ Installation failed"
        return 1
    fi
}

# Function: install_cloudflared_binary
# Description: Installs cloudflared binary directly to /usr/local/bin
install_cloudflared_binary() {
    local arch="$1"
    echo "Installing cloudflared binary to /usr/local/bin..."

    local binary_url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$arch"

    if wget -q "$binary_url" -O cloudflared; then
        chmod +x cloudflared
        sudo mv cloudflared /usr/local/bin/
        echo "✅ Binary installed successfully"
    else
        echo "❌ Failed to download cloudflared binary"
        return 1
    fi
}
