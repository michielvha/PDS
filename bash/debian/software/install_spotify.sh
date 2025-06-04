#!/bin/bash
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/debian/software/install_spotify.sh) `

# Description: Installs and configures PowerShell on Debian-based systems
# Function: install_spotify
# Reference: https://www.spotify.com/us/download/linux/
install_spotify() {
    curl -sS https://download.spotify.com/debian/pubkey_C85668DF69375001.gpg | \
    sudo gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/spotify.gpg
    echo "deb https://repository.spotify.com stable non-free" | sudo tee /etc/apt/sources.list.d/spotify.list

    sudo apt-get update && sudo apt-get install spotify-client
}