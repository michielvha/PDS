#!/bin/bash
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/debian/software/install_pwsh.sh) `

# Description: Installs and configures PowerShell on Debian-based systems
# Function: install_pwsh
install_pwsh() {
    # wrap this with a latest parameter, when we set latest don't exit out if pwsh is already installed
    # Check if PowerShell is already installed
    # if command -v pwsh &> /dev/null; then
    #     echo "PowerShell is already installed."
    #     return
    # fi

    sudo apt update

    command -v wget &> /dev/null || {
        echo "wget could not be found, installing..."
        sudo apt install wget -y
        return
    }
    
    # Download the Microsoft repository GPG keys
    wget -q https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb
    # Register the Microsoft repository GPG keys & Remove the downloaded file
    sudo dpkg -i packages-microsoft-prod.deb && rm packages-microsoft-prod.deb

    sudo apt update && sudo apt install powershell -y
}