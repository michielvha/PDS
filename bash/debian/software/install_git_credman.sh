#!/bin/bash
# Function: install_git_cm
# Description: Downloads and installs the git-credential-manager (GCM) for Linux
# Source: `source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/debian/software/install_git_cm.sh)`

install_git_credman() {
    sudo apt install -y gnupg
    wget https://github.com/GitCredentialManager/git-credential-manager/releases/latest/download/gcm-linux_amd64.2.6.1.deb
    sudo dpkg -i gcm-linux_amd64.2.6.1.deb
    git config --global credential.helper manager-core
}