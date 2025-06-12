#!/bin/bash
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/debian/software/xbox.sh) `

# Function: install_xbox_controller
# Description: Installs the Xbox controller driver on Debian-based systems
# Reference: https://github.com/dlundqvist/xone
install_xbox_controller() {
    echo "📦 installing xbox controller support"
    git clone https://github.com/dlundqvist/xone
    cd xone
    sudo ./install.sh
    cd install
    chmod +x firmware.sh
    sudo ./firmware.sh

    sudo depmod -a
    sudo modprobe xone-gip
    sudo modprobe xone-dongle
    lsmod | grep xone
    echo "✅ Xbox controller support installed successfully."

}