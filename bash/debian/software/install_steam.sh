#!/bin/bash
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/debian/software/install_steam.sh) `

# Function: install_steam
# Description: Downloads and installs the Steam client on Debian-based systems.
install_steam() {
    echo "📦 installing steam"
    wget https://cdn.akamai.steamstatic.com/client/installer/steam.deb
    sudo apt install ./steam.deb
}