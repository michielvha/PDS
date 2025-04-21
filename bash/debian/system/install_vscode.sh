#!/bin/bash
# Function: install_vscode
# Description: Installs Visual Studio Code on a Debian-based system by adding the Microsoft repository and installing the package.
# Usage: install_vscode
# Arguments: none
# Returns:
#   0 - Success
#   1 - Failure (e.g., missing dependencies, repository issues, or installation errors)
# Source: `source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/debian/system/install_vscode.sh)`

function install_vscode () {
    sudo apt install wget gpg apt-transport-https
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
    sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
    echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" |sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
    rm -f packages.microsoft.gpg
    sudo apt update
    sudo apt install code
}
