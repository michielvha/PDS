#!/bin/bash
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/fedora/software/install_signal.sh) `

# Function: install_signal
# Description: Installs Signal messenger on Fedora-based systems
install_signal() {
    # Enable Flathub if not already enabled
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

    # Install Signal
    flatpak install flathub org.signal.Signal

    # Run Signal
    flatpak run org.signal.Signal
}