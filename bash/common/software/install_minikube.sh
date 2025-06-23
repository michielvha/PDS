#!/bin/bash
# shellcheck disable=SC2016
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/common/software/minikube.sh) `

# Function: install_minikube
# Description: Installs the latest version of minikube.
# Reference: https://minikube.sigs.k8s.io/docs/start/?arch=%2Flinux%2Fx86-64%2Fstable%2Fbinary+download
install_minikube() {
    # Check if minikube is already installed
    if command -v minikube &> /dev/null; then
        echo "Minikube is already installed."
        return
    fi

    # Check if curl is installed
    command -v curl &> /dev/null || {
        echo "curl could not be found, installing..."
        sudo apt install curl -y
    }

    # Download the latest version of minikube
    echo "Downloading the latest version of minikube..."
    curl -LO https://github.com/kubernetes/minikube/releases/latest/download/minikube-linux-amd64/

    # Install minikube
    echo "Installing minikube..."
    sudo install minikube-linux-amd64 /usr/local/bin/minikube && rm minikube-linux-amd64

    echo "Minikube installed successfully!"
}