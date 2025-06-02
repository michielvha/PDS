#!/bin/bash
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/debian/system/install_docker.sh) `

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
}
