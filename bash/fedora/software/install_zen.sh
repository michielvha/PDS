#!/bin/bash
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/fedora/software/install_zen.sh) `

# Function: install_zen
# Description: Installs Zen Browser on Fedora-based systems
install_zen() {
    # Enable Flathub if not already enabled
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || {
        echo "❌ Failed to add Flathub remote"
        return 1
    }

    echo "🌐 Installing Zen Browser..."
    flatpak install -y flathub app.zen_browser.zen || {
        echo "❌ Failed to install Zen Browser"
        return 1
    }

    echo "✅ Zen Browser installed successfully!"
    echo "ℹ️  Run 'flatpak run app.zen_browser.zen' to start Zen Browser"
}

