#!/bin/bash
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/fedora/software/install_vscode.sh) `

# Function: install_vscode
# Description: Installs Visual Studio Code on Fedora by adding the official Microsoft RPM repository and installing the native package (no Flatpak sandbox).
install_vscode() {
	echo "🔧 Adding Microsoft GPG key and repository for Visual Studio Code..."
	sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
	sudo sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
	sudo dnf check-update || true
	sudo dnf install -y code
}
