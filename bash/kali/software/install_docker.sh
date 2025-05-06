#!/bin/bash
# source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/kali/software/install_docker.sh) `

# Function: install_docker
# Description: Installs and configures Docker on Kali Linux
# Reference: https://docs.docker.com/engine/install/debian/
install_docker() {
    # Check if Docker is already installed
    if command -v docker &> /dev/null; then
        echo "Docker is already installed."
        return
    fi

    # Check if curl is installed
    command -v curl &> /dev/null || {
        echo "curl could not be found, installing..."
        sudo apt install curl -y
    }

    # Add Docker's official GPG key:
    sudo apt-get update
    sudo apt-get install ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # Add the repository to Apt sources:
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
    bookworm stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update -y

    sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    sudo usermod -aG docker "$USER" && newgrp docker
}
