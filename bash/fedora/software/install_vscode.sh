#!/bin/bash
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/fedora/software/install_vscode.sh) `

# Function: install_vscode
# Description: Installs Visual Studio Code on Fedora via Flatpak (Flathub). Prefer Flatpak for sandboxing and easier updates.
install_vscode() {
    # Enable Flathub if not already enabled
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

    # Install VS Code
    flatpak install flathub com.visualstudio.code -y
}
