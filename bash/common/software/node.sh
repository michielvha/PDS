#!/bin/bash
# shellcheck disable=SC2016
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/common/software/node.sh) `

# Source utility functions
# shellcheck source=/dev/null
source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/common/utils/detect_distro.sh 2>/dev/null || echo "# detect_distro.sh not available")
# shellcheck source=/dev/null
source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/common/utils/detect_arch.sh 2>/dev/null || echo "# detect_arch.sh not available")

# Function: install_node
# Description: Installs Node.js 24.x (newest LTS - "Krypton" as of 2025) on various platforms
#              Supports: Debian/Ubuntu, Fedora/RHEL, Arch, macOS, and others via binary installation
install_node() {
    local os_release
    local package_manager
    local arch
    local node_version="24"

    echo "📦 Installing Node.js ${node_version}.x..."

    # Detect OS and package manager
    os_release=$(get_os_release)
    package_manager=$(get_package_manager)
    arch=$(detect_arch)

    echo "🔍 Detected system: $os_release ($arch)"
    echo "📦 Package manager: $package_manager"

    # Install based on distribution
    case "$os_release" in
        ubuntu|debian)
            echo "📦 Installing via NodeSource repository (Debian/Ubuntu)..."
            # Remove old Ubuntu packages if present
            if command -v nodejs &> /dev/null || command -v npm &> /dev/null; then
                sudo apt remove -y nodejs npm 2>/dev/null || true
            fi
            # Install Node.js via NodeSource
            curl -fsSL https://deb.nodesource.com/setup_${node_version}.x | sudo -E bash -
            sudo apt-get install -y nodejs
            ;;

        fedora|centos|rhel|ol|rocky|almalinux|amzn)
            echo "📦 Installing via NodeSource repository (RHEL-based)..."
            # Remove old packages if present
            if [[ "$package_manager" == "dnf" ]]; then
                sudo dnf remove -y nodejs npm 2>/dev/null || true
                curl -fsSL https://rpm.nodesource.com/setup_${node_version}.x | sudo bash -
                sudo dnf install -y nodejs
            else
                sudo yum remove -y nodejs npm 2>/dev/null || true
                curl -fsSL https://rpm.nodesource.com/setup_${node_version}.x | sudo bash -
                sudo yum install -y nodejs
            fi
            ;;

        arch|manjaro)
            echo "📦 Installing via AUR (Arch-based)..."
            if command -v yay &> /dev/null; then
                yay -S --noconfirm nodejs-lts-krypton npm
            elif command -v paru &> /dev/null; then
                paru -S --noconfirm nodejs-lts-krypton npm
            else
                echo "⚠️  No AUR helper found (yay/paru). Installing binary directly..."
                install_node_binary "$arch" "$node_version"
            fi
            ;;

        macos)
            echo "📦 Installing via Homebrew (macOS)..."
            if command -v brew &> /dev/null; then
                brew install node@${node_version} || brew install node
            else
                echo "⚠️  Homebrew not found. Installing binary directly..."
                install_node_binary "$arch" "$node_version"
            fi
            ;;

        *)
            echo "⚠️  Unknown distribution. Installing binary directly..."
            install_node_binary "$arch" "$node_version"
            ;;
    esac

    # Verify installation
    if command -v node &> /dev/null; then
        echo ""
        echo "✅ Node.js installed successfully!"
        echo "📋 Node.js version: $(node --version)"
        echo "📋 npm version: $(npm --version)"
    else
        echo "❌ Installation failed - Node.js not found in PATH"
        return 1
    fi
}

# Function: install_nvm
# Description: Installs nvm (Node Version Manager) - platform agnostic installation
#              nvm allows you to install and manage multiple Node.js versions
# Reference: https://github.com/nvm-sh/nvm
install_nvm() {
    local nvm_dir="$HOME/.nvm"
    local nvm_url="https://github.com/nvm-sh/nvm.git"
    local detected_shell="bash"
    local shell_rc

    echo "📦 Installing nvm (Node Version Manager)..."

    # Check if nvm is already installed
    if [[ -d "$nvm_dir" ]] && [[ -f "$nvm_dir/nvm.sh" ]]; then
        echo "ℹ️  nvm is already installed at $nvm_dir"
        echo "💡 To update nvm, run: (cd $nvm_dir && git pull)"
        return 0
    fi

    # Check if git is installed
    if ! command -v git &> /dev/null; then
        echo "❌ Git is required to install nvm. Please install git first."
        return 1
    fi

    # Clone nvm repository
    echo "📥 Cloning nvm repository..."
    if git clone "$nvm_url" "$nvm_dir" 2>/dev/null || [[ -d "$nvm_dir" ]]; then
        echo "✅ nvm repository cloned successfully"
    else
        echo "❌ Failed to clone nvm repository"
        return 1
    fi

    # Checkout the latest version tag
    echo "📋 Checking out latest nvm version..."
    (
        cd "$nvm_dir" || return 1
        git fetch --tags --quiet
        local latest_tag
        latest_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "master")
        git checkout "$latest_tag" --quiet 2>/dev/null || true
    )

    # Detect user's shell and use appropriate config file
    case "${SHELL:-}" in
        *zsh*)
            detected_shell="zsh"
            ;;
        *bash*)
            detected_shell="bash"
            ;;
        *)
            # Fallback: check config files
            if [[ -f "$HOME/.zshrc" ]] && [[ ! -f "$HOME/.bashrc" ]]; then
                detected_shell="zsh"
            fi
            ;;
    esac

    case "$detected_shell" in
        zsh)
            shell_rc="$HOME/.zshrc"
            ;;
        bash|*)
            shell_rc="$HOME/.bashrc"
            ;;
    esac

    # Add nvm configuration to shell rc file
    echo "🔧 Configuring nvm in $shell_rc..."
    if ! grep -q "NVM_DIR" "$shell_rc" 2>/dev/null; then
        {
            echo ''
            echo '# nvm (Node Version Manager)'
            echo 'export NVM_DIR="$HOME/.nvm"'
            echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm'
            echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion'
        } >>"$shell_rc"
        echo "✅ nvm configuration added to $shell_rc"
    else
        echo "ℹ️  nvm configuration already exists in $shell_rc"
    fi

    # Load nvm in current shell session
    export NVM_DIR="$HOME/.nvm"
    # shellcheck source=/dev/null
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

    # Verify installation
    if command -v nvm &> /dev/null || [[ -f "$nvm_dir/nvm.sh" ]]; then
        echo ""
        echo "✅ nvm installed successfully!"
        echo "📋 nvm version: $(nvm --version 2>/dev/null || echo "installed")"
        echo ""
        echo "💡 Usage examples:"
        echo "   nvm install node          # Install latest Node.js"
        echo "   nvm install 24            # Install Node.js 24.x"
        echo "   nvm install --lts         # Install latest LTS"
        echo "   nvm use 24                # Switch to Node.js 24.x"
        echo "   nvm list                  # List installed versions"
        echo ""
        echo "💡 Run 'source $shell_rc' or start a new terminal session to use nvm"
    else
        echo "⚠️  nvm installed but may need a new shell session to be available"
        echo "💡 Run 'source $shell_rc' or start a new terminal session"
    fi
}

# Function: install_node_binary
# Description: Installs Node.js binary directly from nodejs.org
install_node_binary() {
    local arch="${1:-$(detect_arch)}"
    local node_version="${2:-24}"
    local os_type
    local node_arch
    local download_url
    local tarball_name
    local install_dir="/usr/local"

    echo "📥 Installing Node.js binary directly..."

    # Detect OS type for binary download
    os_type=$(detect_os)
    
    # Map architecture to Node.js naming
    case "$arch" in
        x86_64)
            node_arch="x64"
            ;;
        aarch64|arm64)
            node_arch="arm64"
            ;;
        armv7l)
            node_arch="armv7l"
            ;;
        armv6l)
            node_arch="armv6l"
            ;;
        i386|i686)
            node_arch="x86"
            ;;
        *)
            echo "❌ Unsupported architecture for binary installation: $arch"
            return 1
            ;;
    esac

    # Get latest version in the specified major version
    echo "🔍 Fetching latest Node.js ${node_version}.x version..."
    local latest_version
    latest_version=$(curl -s "https://nodejs.org/dist/index.json" | grep -o "\"version\":\"v${node_version}\.[0-9]\+\.[0-9]\+\"" | head -1 | grep -o "v${node_version}\.[0-9]\+\.[0-9]\+" || echo "v${node_version}.0.0")

    if [[ -z "$latest_version" ]]; then
        echo "⚠️  Could not determine latest version, using v${node_version}.0.0"
        latest_version="v${node_version}.0.0"
    fi

    echo "📋 Installing Node.js ${latest_version}"

    # Construct download URL
    if [[ "$os_type" == "darwin" ]]; then
        tarball_name="node-${latest_version}-${os_type}-${node_arch}.tar.gz"
    else
        tarball_name="node-${latest_version}-linux-${node_arch}.tar.xz"
    fi

    download_url="https://nodejs.org/dist/${latest_version}/${tarball_name}"

    echo "📥 Downloading from ${download_url}..."

    # Create temporary directory
    local tmp_dir
    tmp_dir=$(mktemp -d)
    cd "$tmp_dir" || return 1

    # Download and extract
    if curl -fsSL "$download_url" -o "$tarball_name"; then
        echo "📦 Extracting Node.js..."
        if [[ "$tarball_name" == *.tar.xz ]]; then
            tar -xf "$tarball_name"
        else
            tar -xzf "$tarball_name"
        fi

        # Remove old installation
        sudo rm -rf "${install_dir}/lib/node_modules" "${install_dir}/bin/node" "${install_dir}/bin/npm" "${install_dir}/bin/npx" "${install_dir}/share/man/man1/node.1" 2>/dev/null || true

        # Install to /usr/local
        if [[ "$os_type" == "darwin" ]]; then
            sudo cp -R "node-${latest_version}-${os_type}-${node_arch}"/* "$install_dir/"
        else
            sudo cp -R "node-${latest_version}-linux-${node_arch}"/* "$install_dir/"
        fi

        # Cleanup
        cd - > /dev/null || return 1
        rm -rf "$tmp_dir"

        echo "✅ Node.js binary installed successfully!"
    else
        echo "❌ Failed to download Node.js binary"
        cd - > /dev/null || return 1
        rm -rf "$tmp_dir"
        return 1
    fi
}

