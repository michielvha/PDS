#!/bin/bash
# PDS Software Installation Functions
# This library contains functions for installing various software packages

# Function: install_docker
# Description: Installs and configures Docker on Debian-based systems
install_docker() {
    echo "🐳 Installing Docker..."
    
    # Clean up any old docker packages
    for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do 
        sudo apt-get remove "$pkg" 2>/dev/null || true
    done

    # Add Docker's official GPG key:
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # Add the repository to Apt sources:
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update
    
    # Install Docker
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Verify installation
    if command -v docker &> /dev/null; then
        echo "✅ Docker installed successfully"
    else
        echo "❌ Docker installation failed"
        return 1
    fi

    # Add the current user to the docker group
    sudo groupadd docker 2>/dev/null || true
    sudo usermod -aG docker "$USER"
    
    # Enable Docker to start on boot
    sudo systemctl enable docker
    
    echo "📝 Note: You may need to log out and back in for Docker group membership to take effect"
}

# Function: install_vscode
# Description: Installs Visual Studio Code on a Debian-based system
install_vscode() {
    echo "📝 Installing Visual Studio Code..."
    
    # Install dependencies
    sudo apt-get update
    sudo apt-get install -y software-properties-common apt-transport-https curl
    
    # Add Microsoft GPG key
    curl -sSL https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor --output /usr/share/keyrings/microsoft-archive-keyring.gpg
    
    # Add VS Code repository
    echo "deb [arch=amd64,arm64,armhf signed-by=/usr/share/keyrings/microsoft-archive-keyring.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list
    
    # Update and install
    sudo apt-get update
    sudo apt-get install -y code
    
    if command -v code &> /dev/null; then
        echo "✅ Visual Studio Code installed successfully"
    else
        echo "❌ Visual Studio Code installation failed"
        return 1
    fi
}

# Function: install_kubectl
# Description: Installs and configures kubectl
install_kubectl() {
    echo "☸️ Installing kubectl..."
    
    # Install dependencies
    sudo apt-get update
    sudo apt-get install -y apt-transport-https ca-certificates curl gnupg
    
    # Add Kubernetes GPG key
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    
    # Add Kubernetes repository
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
    
    # Update and install
    sudo apt-get update
    sudo apt-get install -y kubectl
    
    if command -v kubectl &> /dev/null; then
        echo "✅ kubectl installed successfully"
        kubectl version --client
    else
        echo "❌ kubectl installation failed"
        return 1
    fi
}

# Function: install_azcli
# Description: Installs and configures the Azure CLI
install_azcli() {
    echo "☁️ Installing Azure CLI..."
    
    # Install dependencies
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl apt-transport-https lsb-release gnupg
    
    # Add Microsoft GPG key
    curl -sLS https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /etc/apt/keyrings/microsoft.gpg > /dev/null
    sudo chmod go+r /etc/apt/keyrings/microsoft.gpg
    
    # Add Azure CLI repository
    AZ_REPO=$(lsb_release -cs)
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" | sudo tee /etc/apt/sources.list.d/azure-cli.list
    
    # Update and install
    sudo apt-get update
    sudo apt-get install -y azure-cli
    
    if command -v az &> /dev/null; then
        echo "✅ Azure CLI installed successfully"
        az version
    else
        echo "❌ Azure CLI installation failed"
        return 1
    fi
}

# Function: install_git_credman
# Description: Downloads and installs the git-credential-manager (GCM) for Linux
install_git_credman() {
    echo "🔐 Installing Git Credential Manager..."
    
    # Get the latest release
    local latest_url
    latest_url=$(curl -s https://api.github.com/repos/git-ecosystem/git-credential-manager/releases/latest | grep "browser_download_url.*gcm-linux_amd64.*deb" | cut -d '"' -f 4)
    
    if [ -z "$latest_url" ]; then
        echo "❌ Could not find latest GCM release"
        return 1
    fi
    
    # Download and install
    local temp_file="/tmp/gcm-linux.deb"
    curl -fsSL "$latest_url" -o "$temp_file"
    sudo dpkg -i "$temp_file"
    
    # Clean up
    rm -f "$temp_file"
    
    if command -v git-credential-manager &> /dev/null; then
        echo "✅ Git Credential Manager installed successfully"
        git-credential-manager --version
    else
        echo "❌ Git Credential Manager installation failed"
        return 1
    fi
}

# Function: install_pwsh
# Description: Installs PowerShell Core on Linux
install_pwsh() {
    echo "💻 Installing PowerShell Core..."
    
    # Install dependencies
    sudo apt-get update
    sudo apt-get install -y wget apt-transport-https software-properties-common
    
    # Add Microsoft repository
    source /etc/os-release
    wget -q "https://packages.microsoft.com/config/ubuntu/${VERSION_ID}/packages-microsoft-prod.deb"
    sudo dpkg -i packages-microsoft-prod.deb
    rm packages-microsoft-prod.deb
    
    # Update and install
    sudo apt-get update
    sudo apt-get install -y powershell
    
    if command -v pwsh &> /dev/null; then
        echo "✅ PowerShell Core installed successfully"
        pwsh --version
    else
        echo "❌ PowerShell Core installation failed"
        return 1
    fi
}

# Function: install_steam
# Description: Installs Steam gaming platform
install_steam() {
    echo "🎮 Installing Steam..."
    
    # Enable 32-bit architecture (required for Steam)
    sudo dpkg --add-architecture i386
    sudo apt-get update
    
    # Install Steam
    sudo apt-get install -y steam
    
    if command -v steam &> /dev/null; then
        echo "✅ Steam installed successfully"
    else
        echo "❌ Steam installation failed"
        return 1
    fi
}

# Function: install_spotify
# Description: Installs Spotify music player
install_spotify() {
    echo "🎵 Installing Spotify..."
    
    # Add Spotify GPG key
    curl -sS https://download.spotify.com/debian/pubkey_6224F9941A8AA6D1.gpg | sudo gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/spotify.gpg
    
    # Add Spotify repository
    echo "deb http://repository.spotify.com stable non-free" | sudo tee /etc/apt/sources.list.d/spotify.list
    
    # Update and install
    sudo apt-get update
    sudo apt-get install -y spotify-client
    
    if command -v spotify &> /dev/null; then
        echo "✅ Spotify installed successfully"
    else
        echo "❌ Spotify installation failed"
        return 1
    fi
}

# Function: install_signal
# Description: Installs Signal messenger
install_signal() {
    echo "📱 Installing Signal..."
    
    # Add Signal GPG key
    wget -O- https://updates.signal.org/desktop/apt/keys.asc | gpg --dearmor > signal-desktop-keyring.gpg
    cat signal-desktop-keyring.gpg | sudo tee /usr/share/keyrings/signal-desktop-keyring.gpg > /dev/null
    
    # Add Signal repository
    echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/signal-desktop-keyring.gpg] https://updates.signal.org/desktop/apt xenial main' | sudo tee /etc/apt/sources.list.d/signal-xenial.list
    
    # Update and install
    sudo apt-get update
    sudo apt-get install -y signal-desktop
    
    # Clean up
    rm -f signal-desktop-keyring.gpg
    
    if command -v signal-desktop &> /dev/null; then
        echo "✅ Signal installed successfully"
    else
        echo "❌ Signal installation failed"
        return 1
    fi
}
