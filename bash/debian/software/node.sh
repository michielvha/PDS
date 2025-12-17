#!/bin/bash
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/debian/software/node.sh) `

# Function: install_node
# Description: Installs Node.js 24.x (newest LTS - "Krypton" as of 2025)
install_node() {
    echo "📦 Installing Node.js 24.x..."
    # Remove old Ubuntu packages
    sudo apt remove nodejs npm

    # Install Node.js
    curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash -
    sudo apt-get install -y nodejs

    # Verify
    node --version  # Should be v24.x.x
    npm --version   # Should be 10.x.x
}
