#!/bin/bash

# This module contains functions used for installing various tools / software.

# ------------------------------------------------------------------------------------------------------------------------------------------------
# Function: full upgrade with one command
function install_awscli() {

    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install

    # Detect the shell and update the respective config file with path addition
#    case "$0" in
#        *zsh) echo 'export PATH=$PATH:/usr/local/bin/' >> ~/.zshrc ;;
#        *bash) echo 'export PATH=$PATH:/usr/local/bin/' >> ~/.bashrc ;;
#        *) echo "Unknown shell: $0. Please add AWS CLI path manually." ;;
#    esac

    # Clean up
    rm -rf awscliv2.zip aws/

    # Verify AWS CLI installation
    aws --version
}

# ------------------------------------------------------------------------------------------------------------------------------------------------
# Function: Install kubernetes on debian based systems
function install_kubectl() {
    sudo apt update -y
    sudo apt install -y apt-transport-https ca-certificates curl gnupg
    sudo mkdir -p -m 755 /etc/apt/keyrings
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg # allow unprivileged APT programs to read this keyring
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
    sudo chmod 644 /etc/apt/sources.list.d/kubernetes.list   # helps tools such as command-not-found to work correctly
    sudo apt update
    sudo apt install -y kubectl
}

# ------------------------------------------------------------------------------------------------------------------------------------------------
# Function: Install azure cli on any supported linux system
function install_azcli() {
  # quick and easy script maintained by microsoft. Do not use in production.
  curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
}

function install_azcli_safe() {
  sudo apt-get update -y
  sudo apt-get install apt-transport-https ca-certificates curl gnupg lsb-release -y

  sudo mkdir -p /etc/apt/keyrings
  curl -sLS https://packages.microsoft.com/keys/microsoft.asc |
    gpg --dearmor | sudo tee /etc/apt/keyrings/microsoft.gpg > /dev/null
  sudo chmod go+r /etc/apt/keyrings/microsoft.gpg

  AZ_DIST=$(lsb_release -cs)
  echo "Types: deb
  URIs: https://packages.microsoft.com/repos/azure-cli/
  Suites: ${AZ_DIST}
  Components: main
  Architectures: $(dpkg --print-architecture)
  Signed-by: /etc/apt/keyrings/microsoft.gpg" | sudo tee /etc/apt/sources.list.d/azure-cli.sources

  sudo apt update -y
  sudo apt install azure-cli -y
}