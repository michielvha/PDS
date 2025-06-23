#!/bin/bash
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/debian/software/install_signal.sh) `

# Function: install_signal
# Description: Installs signal-desktop on Debian-based Linux distributions.
# Reference: https://signal.org/download/linux/
install_signal() {
	# NOTE: These instructions only work for 64-bit Debian-based
	# Linux distributions such as Ubuntu, Mint etc.

	# 1. Install our official public software signing key:
	wget -O- https://updates.signal.org/desktop/apt/keys.asc | gpg --dearmor > signal-desktop-keyring.gpg;
	cat signal-desktop-keyring.gpg | sudo tee /usr/share/keyrings/signal-desktop-keyring.gpg > /dev/null

	# 2. Add our repository to your list of repositories:
	echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/signal-desktop-keyring.gpg] https://updates.signal.org/desktop/apt xenial main' |\
	sudo tee /etc/apt/sources.list.d/signal-xenial.list

	# 3. Update your package database and install Signal:
	sudo apt update && sudo apt install signal-desktop
}

