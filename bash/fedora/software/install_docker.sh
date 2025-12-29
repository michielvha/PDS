#!/bin/bash
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/fedora/software/install_docker.sh) `

# Function: install_docker
# Description: Installs and configures Docker on Fedora-based systems
install_docker() {

    echo "🐳 Removing old docker packages..."
    sudo dnf remove docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-selinux docker-engine-selinux docker-engine

    echo "🐳 Adding Docker's repository..."
    sudo dnf config-manager addrepo --from-repofile https://download.docker.com/linux/fedora/docker-ce.repo

    echo "🐳 Installing latest version of Docker..."
    sudo dnf install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    echo "🐳 Starting and enabling Docker..."
    sudo systemctl start docker
    sudo systemctl enable --now docker

    echo "🐳 Adding current user to docker group..."
    sudo usermod -aG docker "$USER"
    
    echo "🐳 Verifying Docker installation..."
    sudo docker --version

    echo "🐳 Note: You may need to log out and back in for Docker group membership to take effect"
}
