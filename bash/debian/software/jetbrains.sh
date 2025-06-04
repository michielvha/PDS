#!/bin/bash
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/debian/software/hashicorp.sh) `

# Function: install_pycharm
# Description: Installs JetBrains PyCharm on a Debian-based system
install_pycharm() {
    # initialize variables
    local INSTALL_LOCATION="$HOME/pycharm-ce"
    local EXE_LOCATION="$HOME/bin/pycharm"
    local VERSION="2025.1.1.1"
    # ensure path exists
    mkdir -p ~/.local/bin
    mkdir -p ~/.local/share/applications
    mkdir -p "$INSTALL_LOCATION"
    
    echo "🔄 Installing JetBrains PyCharm..."

    # Download and extract directly to pycharm-community
    curl -L https://download.jetbrains.com/python/pycharm-community-$VERSION.tar.gz | tar -xz --strip-components=1 -C "$INSTALL_LOCATION"
    ln -sf "$EXE_LOCATION" ~/.local/bin

    # Create desktop entry
    cat << EOF | tee ~/.local/share/applications/pycharm.desktop
[Desktop Entry]
Version=${VERSION}
Type=Application
Name=PyCharm Community Edition
Icon=$INSTALL_LOCATION/bin/pycharm.png
Exec=$EXE_LOCATION
Comment=Python IDE for Professional Developers
Categories=Development;IDE;
Terminal=false
StartupWMClass=jetbrains-pycharm-ce
StartupNotify=true    
EOF
}