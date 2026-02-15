#!/bin/bash
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/debian/software/install_docker.sh) `

# Function: install_docker
# Description: Installs and configures Docker on Debian-based systems (Ubuntu or Debian)
install_docker() {
	# Detect OS (Ubuntu or Debian)
	# shellcheck disable=SC1091 # /etc/os-release is a system file and always present
	if [[ -f /etc/os-release ]]; then
		. /etc/os-release
	else
		echo "❌ Cannot detect OS: /etc/os-release not found"
		return 1
	fi

	case "$ID" in
		ubuntu)
			_docker_install_ubuntu
			;;
		debian)
			_docker_install_debian
			;;
		*)
			echo "❌ Unsupported OS: $ID. This script supports Ubuntu and Debian only."
			return 1
			;;
	esac || return $?

	# Common steps after adding repo and installing packages
	_docker_install_common
}

_docker_install_ubuntu() {
	# Clean up any old docker packages
	for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt-get remove -y $pkg 2>/dev/null; done

	sudo apt-get update
	sudo apt-get install -y ca-certificates curl
	sudo install -m 0755 -d /etc/apt/keyrings
	sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
	sudo chmod a+r /etc/apt/keyrings/docker.asc

	echo \
	"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
	$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
	sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
	sudo apt-get update
	sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

_docker_install_debian() {
	# Clean up any old docker packages
	for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt-get remove -y $pkg 2>/dev/null; done

	sudo apt-get update
	sudo apt-get install -y ca-certificates curl
	sudo install -m 0755 -d /etc/apt/keyrings
	sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
	sudo chmod a+r /etc/apt/keyrings/docker.asc

	sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

	sudo apt-get update
	sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

_docker_install_common() {

	# Verify installation
	command -v docker &> /dev/null && echo "✅ Docker installed" || echo "❌ Docker command failed, check installation"

	# Add the current user to the docker group
	sudo groupadd docker 2>/dev/null || true
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
	    echo "Starting new shell"
		exec su -l $USER
	else
	    echo "Skipping. Please log out and log back in, or run 'newgrp docker' manually."
	fi
}
