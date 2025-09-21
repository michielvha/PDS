#!/bin/bash
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/common/software/install_bat.sh) `

# Source utility functions
# shellcheck source=/dev/null
source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/common/utils/detect_distro.sh)

# Function: install_bat
# Description: Installs bat command-line tool on various Linux distributions and other systems
install_bat() {
    local os_release
    local package_manager
    
    os_release=$(get_os_release)
    package_manager=$(get_package_manager)
    
    echo "Detected OS: $os_release"
    echo "Package manager: $package_manager"
    echo "Installing bat..."
    
    case "$os_release" in
        ubuntu|debian)
            # Check Ubuntu/Debian version
            if command -v lsb_release >/dev/null 2>&1; then
                local version
                version=$(lsb_release -rs 2>/dev/null | cut -d. -f1)
                
                # Ubuntu 20.04+ and Debian 11+ have bat in repositories
                if [[ "$os_release" == "ubuntu" && "${version:-0}" -ge 20 ]] || 
                   [[ "$os_release" == "debian" && "${version:-0}" -ge 11 ]]; then
                    echo "Installing bat via apt..."
                    sudo apt update
                    sudo apt install -y bat
                    
                    # Create symlink if bat was installed as batcat
                    if command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1; then
                        echo "Creating bat symlink (batcat -> bat)..."
                        mkdir -p ~/.local/bin
                        ln -sf /usr/bin/batcat ~/.local/bin/bat
                        echo "Added ~/.local/bin to PATH if not already present"
                        echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
                        echo "You may want to add 'alias bat=batcat' to your shell configuration"
                    fi
                else
                    # Install from .deb package for older versions
                    install_bat_from_deb
                fi
            else
                # Fallback: try apt first, then .deb
                sudo apt update
                if sudo apt install -y bat 2>/dev/null; then
                    echo "✅ bat installed via apt"
                    # Handle batcat symlink
                    if command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1; then
                        mkdir -p ~/.local/bin
                        ln -sf /usr/bin/batcat ~/.local/bin/bat
                        echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
                    fi
                else
                    echo "apt install failed, trying .deb package..."
                    install_bat_from_deb
                fi
            fi
            ;;
            
        fedora|centos|rhel)
            echo "Installing bat via $package_manager..."
            sudo $package_manager install -y bat
            ;;
            
        arch|manjaro)
            echo "Installing bat via pacman..."
            sudo pacman -S --noconfirm bat
            ;;
            
        opensuse*|suse*)
            echo "Installing bat via zypper..."
            sudo zypper install -y bat
            ;;
            
        alpine)
            echo "Installing bat via apk..."
            sudo apk add bat
            ;;
            
        gentoo)
            echo "Installing bat via emerge..."
            sudo emerge sys-apps/bat
            ;;
            
        freebsd)
            echo "Installing bat via pkg..."
            sudo pkg install -y bat
            ;;
            
        openbsd)
            echo "Installing bat via pkg_add..."
            sudo pkg_add bat
            ;;
            
        *)
            echo "❌ Unsupported operating system: $os_release"
            echo "Please install bat manually or via your system's package manager"
            echo "Visit: https://github.com/sharkdp/bat#installation"
            return 1
            ;;
    esac
    
    # Verify installation
    if command -v bat >/dev/null 2>&1; then
        echo "✅ bat successfully installed"
        echo "Version: $(bat --version)"
        
        # Show usage tip
        echo ""
        echo "Usage examples:"
        echo "  bat file.txt                 # View file with syntax highlighting"
        echo "  bat -A file.txt              # Show all characters including non-printable"
        echo "  bat --style=numbers file.txt # Show line numbers"
        echo "  echo 'hello' | bat -l sh     # Pipe with syntax highlighting"
    else
        echo "❌ bat installation failed or command not found"
        echo "You may need to:"
        echo "  1. Restart your shell or run: source ~/.bashrc"
        echo "  2. Check if ~/.local/bin is in your PATH"
        echo "  3. Use 'batcat' instead of 'bat' on some systems"
        return 1
    fi
}

# Function: install_bat_from_deb
# Description: Installs bat from the latest .deb package
install_bat_from_deb() {
    echo "Installing bat from .deb package..."
    
    # Get latest release info from GitHub API
    local latest_url
    latest_url=$(curl -s https://api.github.com/repos/sharkdp/bat/releases/latest | grep "browser_download_url.*amd64.deb" | cut -d '"' -f 4)
    
    if [[ -z "$latest_url" ]]; then
        echo "❌ Could not find latest .deb package URL"
        return 1
    fi
    
    local temp_file="/tmp/bat_latest_amd64.deb"
    
    # Download and install
    echo "Downloading: $latest_url"
    if curl -L -o "$temp_file" "$latest_url"; then
        echo "Installing .deb package..."
        sudo dpkg -i "$temp_file"
        
        # Fix any dependency issues
        sudo apt-get install -f -y
        
        # Clean up
        rm -f "$temp_file"
        echo "✅ bat installed from .deb package"
    else
        echo "❌ Failed to download .deb package"
        rm -f "$temp_file"
        return 1
    fi
}

# Function: setup_bat_alias
# Description: Sets up alias for batcat -> bat if needed
setup_bat_alias() {
    if command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1; then
        echo "Setting up bat alias for batcat..."
        
        # Add to bashrc if not already present
        if ! grep -q "alias bat=" ~/.bashrc 2>/dev/null; then
            echo 'alias bat="batcat"' >> ~/.bashrc
            echo "Added 'alias bat=batcat' to ~/.bashrc"
        fi
        
        # Add to zshrc if it exists and alias not present
        if [[ -f ~/.zshrc ]] && ! grep -q "alias bat=" ~/.zshrc 2>/dev/null; then
            echo 'alias bat="batcat"' >> ~/.zshrc
            echo "Added 'alias bat=batcat' to ~/.zshrc"
        fi
        
        echo "Please restart your shell or run: source ~/.bashrc"
    fi
}