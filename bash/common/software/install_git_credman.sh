#!/bin/bash
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/common/software/install_git_credman.sh) `

# Source utility functions
# shellcheck source=/dev/null
source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/common/utils/detect_distro.sh 2>/dev/null || echo "# detect_distro.sh not available")
# shellcheck source=/dev/null
source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/common/utils/detect_arch.sh 2>/dev/null || echo "# detect_arch.sh not available")

# Function: install_git_credman
# Description: Downloads and installs the git-credential-manager (GCM) for Linux with proper setup for headless/TTY environments using GPG encryption.
#              Supports both Debian-based (.deb) and RPM-based (.rpm) distributions.
# Reference: [Backend] - https://github.com/git-ecosystem/git-credential-manager/blob/release/docs/credstores.md
#            [Install] - https://github.com/git-ecosystem/git-credential-manager/blob/release/docs/install.md | https://learn.microsoft.com/en-us/windows/wsl/tutorials/wsl-git
#            [  WSL  ] - https://github.com/git-ecosystem/git-credential-manager/blob/main/docs/wsl.md
#            [Various] - https://stackoverflow.com/questions/45925964/how-to-use-git-credential-store-on-wsl-ubuntu-on-windows
install_git_credman() {
    local os_release
    local package_manager
    local arch
    local download_url
    local package_file
    local version
    local latest_tag
    
    # Detect OS and architecture
    os_release=$(get_os_release)
    package_manager=$(get_package_manager)
    arch=$(map_arch_to_standard)
    
    if [[ $? -ne 0 ]]; then
        echo "❌ Unsupported architecture: $(detect_arch)"
        return 1
    fi
    
    echo "🔍 Detected system: $os_release ($arch)"
    echo "📦 Package manager: $package_manager"
    
    # Install dependencies
    echo "📥 Installing dependencies..."
    case "$os_release" in
        ubuntu|debian)
            sudo apt update
            sudo apt install -y gnupg pass wget curl
            ;;
        fedora|centos|rhel|ol|rocky|almalinux|amzn)
            if [[ "$package_manager" == "dnf" ]]; then
                sudo dnf install -y gnupg pass wget curl
            else
                sudo yum install -y gnupg pass wget curl
            fi
            ;;
        arch|manjaro)
            sudo pacman -S --noconfirm gnupg pass wget curl
            ;;
        opensuse*|suse*)
            sudo zypper install -y gnupg pass wget curl
            ;;
        *)
            echo "⚠️  Unknown distribution. Attempting to install dependencies manually..."
            echo "Please ensure gnupg, pass, wget, and curl are installed."
            ;;
    esac
    
    # Download and install Git Credential Manager
    echo "📥 Downloading latest Git Credential Manager..."
    
    # Get the tag name from the GitHub API
    latest_tag=$(curl -sL https://api.github.com/repos/git-ecosystem/git-credential-manager/releases/latest | grep -o '"tag_name": "v[0-9.]*"' | cut -d'"' -f4)
    
    if [ -n "$latest_tag" ]; then
        # Remove 'v' prefix to get the version number
        echo "📋 Latest version found: $latest_tag"
        version=${latest_tag#v}
    else
        # Fallback to a known version if API call fails
        echo "⚠️  Couldn't get latest version, using fallback version 2.6.1"
        latest_tag="v2.6.1"
        version="2.6.1"
    fi
    
    # Determine package format and download URL based on distribution
    case "$os_release" in
        ubuntu|debian)
            package_file="gcm-linux_${arch}.${version}.deb"
            download_url="https://github.com/git-ecosystem/git-credential-manager/releases/download/${latest_tag}/${package_file}"
            echo "📥 Downloading .deb package from: $download_url"
            wget "$download_url" -O gcm-linux_${arch}.deb
            if [[ $? -eq 0 ]]; then
                sudo dpkg -i gcm-linux_${arch}.deb
                # Fix any dependency issues
                sudo apt-get install -f -y
                rm -f gcm-linux_${arch}.deb
            else
                echo "❌ Failed to download .deb package"
                return 1
            fi
            ;;
        fedora|centos|rhel|ol|rocky|almalinux|amzn|opensuse*|suse*)
            # Git Credential Manager doesn't provide .rpm packages, use binary installation
            echo "📦 RPM-based system detected. Installing binary from .tar.gz (no .rpm available)..."
            install_git_credman_binary "$arch" "$latest_tag" "$version"
            ;;
        arch|manjaro)
            # For Arch-based systems, try AUR first, then fallback to binary
            echo "📦 Arch-based system detected"
            if command -v yay &> /dev/null; then
                echo "Installing via AUR (yay)..."
                yay -S --noconfirm git-credential-manager-bin
            elif command -v paru &> /dev/null; then
                echo "Installing via AUR (paru)..."
                paru -S --noconfirm git-credential-manager-bin
            else
                echo "⚠️  No AUR helper found. Installing binary directly..."
                install_git_credman_binary "$arch" "$latest_tag" "$version"
            fi
            ;;
        *)
            echo "⚠️  Unsupported distribution: $os_release"
            echo "Attempting to install binary directly..."
            install_git_credman_binary "$arch" "$latest_tag" "$version"
            ;;
    esac
    
    # Detect if running in WSL
    if grep -q "microsoft" /proc/version || grep -q "Microsoft" /proc/version || grep -q "WSL" /proc/version; then
        echo "🔍 WSL environment detected, configuring GCM for WSL..."
        
        # For WSL, use the Windows Git Credential Manager
        git config --global credential.helper "/mnt/c/Program\ Files/Git/mingw64/bin/git-credential-manager.exe"
        
        # Set necessary config for Azure DevOps
        git config --global credential.https://dev.azure.com.useHttpPath true
        
        echo ""
        echo "✅ Git Credential Manager configured for WSL"
        echo "----------------------------------------"
        echo "Windows Git Credential Manager will be used for authentication."
        echo "No GPG setup is required as credentials will be managed by Windows."
        echo ""
        
        # Early return - no need for GPG setup in WSL mode
        return 0
    else
        echo "🔍 Standard Linux environment detected, using native GCM..."
        
        # Configure Git to use GCM
        git config --global credential.helper manager
        
        # Configure GCM to use GPG/pass for credential storage
        git config --global credential.credentialStore gpg
        
        # Configure Git to properly handle Azure DevOps URLs
        git config --global credential.useHttpPath true
        
        # Setup for headless/TTY environments - add to both bash and zsh if present
        local gpg_tty_line='export GPG_TTY=$(tty)'
        
        # Add to .bashrc if it exists and the line is not already present
        if [[ -f ~/.bashrc ]]; then
            if ! grep -q "export GPG_TTY=\$(tty)" ~/.bashrc 2>/dev/null; then
                echo "$gpg_tty_line" >> ~/.bashrc
                echo "✅ Added GPG_TTY export to ~/.bashrc"
            else
                echo "ℹ️  GPG_TTY export already present in ~/.bashrc"
            fi
        fi
        
        # Add to .zshrc if it exists and the line is not already present
        if [[ -f ~/.zshrc ]]; then
            if ! grep -q "export GPG_TTY=\$(tty)" ~/.zshrc 2>/dev/null; then
                echo "$gpg_tty_line" >> ~/.zshrc
                echo "✅ Added GPG_TTY export to ~/.zshrc"
            else
                echo "ℹ️  GPG_TTY export already present in ~/.zshrc"
            fi
        fi
        
        # Add to current session
        GPG_TTY=$(tty)
        export GPG_TTY
        
        echo ""
        echo "✅ Git Credential Manager installed with GPG credential store"
        echo "-----------------------------------------------------------"
    fi
    
    # Check if GPG key exists
    if ! gpg --list-secret-keys | grep -q "sec"; then
        echo "🔑 No GPG key found. Creating a new GPG key..."
        
        # Create batch file for non-interactive GPG key generation
        cat > /tmp/gpg-batch << 'EOF'
%echo Generating a GPG key
Key-Type: RSA
Key-Length: 3072
Subkey-Type: RSA
Subkey-Length: 3072
Name-Real: Git Credential Manager
Name-Email: gcm@localhost
Expire-Date: 0
%no-protection
%commit
%echo Done
EOF
        
        # Generate the key
        gpg --batch --generate-key /tmp/gpg-batch
        rm -f /tmp/gpg-batch
        
        echo "✅ GPG key generated successfully!"
    else
        echo "ℹ️  Existing GPG key found."
    fi
    
    # Get the key ID of the first available key
    local GPG_KEY_ID
    GPG_KEY_ID=$(gpg --list-secret-keys --keyid-format LONG | grep -m 1 "sec" | sed -r 's/.*\/([A-Z0-9]+) .*/\1/')
    
    # Check if pass is initialized
    if ! pass ls > /dev/null 2>&1; then
        echo "🔐 Initializing pass with GPG key: $GPG_KEY_ID"
        pass init "$GPG_KEY_ID"
    else
        echo "ℹ️  Pass store already initialized"
    fi
    
    echo ""
    echo "✅ Setup complete! The system is now configured to use GPG for secure credential storage."
    echo "   GPG_TTY export has been automatically added to your shell profile(s)."
    echo ""
}

# Function: install_git_credman_binary
# Description: Installs git-credential-manager binary directly to /usr/local/bin
#              Used as fallback for unsupported distributions or when package managers fail
install_git_credman_binary() {
    local arch="$1"
    local latest_tag="$2"
    local version="$3"
    
    echo "📦 Installing git-credential-manager binary directly..."
    
    local binary_url="https://github.com/git-ecosystem/git-credential-manager/releases/download/${latest_tag}/gcm-linux_${arch}.${version}.tar.gz"
    
    local temp_dir
    temp_dir=$(mktemp -d)
    cd "$temp_dir" || return 1
    
    echo "📥 Downloading from: $binary_url"
    if wget -q "$binary_url" -O gcm.tar.gz || curl -sL "$binary_url" -o gcm.tar.gz; then
        tar -xzf gcm.tar.gz
        # Find the binary in the extracted directory
        if [[ -f git-credential-manager ]]; then
            chmod +x git-credential-manager
            sudo mv git-credential-manager /usr/local/bin/
            
            # Install shared libraries if they exist
            if [[ -f libHarfBuzzSharp.so ]]; then
                sudo mv libHarfBuzzSharp.so /usr/local/lib/ 2>/dev/null || sudo mv libHarfBuzzSharp.so /usr/lib/ 2>/dev/null || true
            fi
            if [[ -f libSkiaSharp.so ]]; then
                sudo mv libSkiaSharp.so /usr/local/lib/ 2>/dev/null || sudo mv libSkiaSharp.so /usr/lib/ 2>/dev/null || true
            fi
            
            echo "✅ Binary installed successfully"
        else
            # Try to find it in subdirectories
            local binary_path
            binary_path=$(find . -name "git-credential-manager" -type f | head -n 1)
            if [[ -n "$binary_path" ]]; then
                chmod +x "$binary_path"
                sudo mv "$binary_path" /usr/local/bin/git-credential-manager
                
                # Install shared libraries if they exist
                local lib_dir
                lib_dir=$(dirname "$binary_path")
                if [[ -f "${lib_dir}/libHarfBuzzSharp.so" ]]; then
                    sudo mv "${lib_dir}/libHarfBuzzSharp.so" /usr/local/lib/ 2>/dev/null || sudo mv "${lib_dir}/libHarfBuzzSharp.so" /usr/lib/ 2>/dev/null || true
                fi
                if [[ -f "${lib_dir}/libSkiaSharp.so" ]]; then
                    sudo mv "${lib_dir}/libSkiaSharp.so" /usr/local/lib/ 2>/dev/null || sudo mv "${lib_dir}/libSkiaSharp.so" /usr/lib/ 2>/dev/null || true
                fi
                
                echo "✅ Binary installed successfully"
            else
                echo "❌ Could not find git-credential-manager binary in archive"
                cd - > /dev/null || return 1
                rm -rf "$temp_dir"
                return 1
            fi
        fi
    else
        echo "❌ Failed to download git-credential-manager binary"
        cd - > /dev/null || return 1
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Cleanup
    cd - > /dev/null || return 1
    rm -rf "$temp_dir"
}

