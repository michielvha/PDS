#!/bin/bash
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/debian/software/install_docker.sh) `

# Function: install_docker
# Description: Installs and configures Docker on Debian-based systems
install_docker() {
	# Clean up any old docker packages
	for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt-get remove $pkg; done

	# Add Docker's official GPG key:
	sudo apt-get update
	sudo apt-get install ca-certificates curl
	sudo install -m 0755 -d /etc/apt/keyrings
	sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
	sudo chmod a+r /etc/apt/keyrings/docker.asc

	# Add the repository to Apt sources:
	# shellcheck disable=SC1091 # /etc/os-release is a system file and always present
	echo \
	"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
	$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
	sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
	sudo apt-get update
	# install
	sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

	# Verify installation
	command -v docker &> /dev/null && echo "✅ Docker installed" || echo "❌ Docker command failed, check installation"

	# Add the current user to the docker group
	sudo groupadd docker
	sudo usermod -aG docker "$USER"
	# Enable Docker to start on boot
	sudo systemctl enable docker
	
	# Prompt user about starting new shell
	echo ""
	echo "User added to docker group successfully!"
	echo "Group changes require a new shell session to take effect."
	echo ""
	read -p "Would you like to start a new shell now? (y/n): " -n 1 -r
	echo ""
	
	if [[ $REPLY =~ ^[Yy]$ ]]; then
	    echo "Starting new shell with docker group..."
	    newgrp docker
	else
	    echo "Skipping. Please log out and log back in, or run 'newgrp docker' manually."
	fi
}
