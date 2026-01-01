#!/bin/bash
# shellcheck disable=SC2016
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/fedora/software/install_brew.sh) `

# Function: install_brew
# Description: Installs Homebrew on Fedora-based systems
install_brew() {
    # Check if brew is already installed
    if command -v brew &> /dev/null; then
        echo "✅ Homebrew is already installed."
        return 0
    fi

    echo "🔧 Installing dependencies..."
    sudo dnf group install -y development-tools || {
        echo "❌ Failed to install development tools group"
        return 1
    }
    
    sudo dnf install -y procps-ng curl file git || {
        echo "❌ Failed to install required packages"
        return 1
    }

    echo "🍺 Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
        echo "❌ Failed to install Homebrew"
        return 1
    }

    # Detect Homebrew installation path and add to PATH
    if [[ -d "$HOME/.linuxbrew" ]]; then
        BREW_PREFIX="$HOME/.linuxbrew"
    elif [[ -d "/home/linuxbrew/.linuxbrew" ]]; then
        BREW_PREFIX="/home/linuxbrew/.linuxbrew"
    else
        # Fallback: try to use brew command if available
        command -v brew &> /dev/null && BREW_PREFIX=$(brew --prefix) || {
            echo "❌ Could not detect Homebrew installation path"
            return 1
        }
    fi

    echo "🔧 Adding Homebrew to PATH..."
    local shell_rc="$HOME/.bashrc"
    
    # Add empty line and brew eval if not already present
    if ! grep -q "brew shellenv" "$shell_rc" 2>/dev/null; then
        {
            echo ''
            echo 'eval "$('"$BREW_PREFIX/bin/brew"' shellenv)"'
        } >> "$shell_rc"
        echo "✅ Added Homebrew to $shell_rc"
    else
        echo "ℹ️  Homebrew already configured in $shell_rc"
    fi

    # Source brew for current session
    eval "$($BREW_PREFIX/bin/brew shellenv)" 2>/dev/null || true

    echo "✅ Homebrew installed successfully!"
    echo "ℹ️  Recommended next step: brew install gcc"
    echo "ℹ️  Run 'brew help' to get started"

    # brew install gcc
}