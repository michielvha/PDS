#!/bin/bash
# shellcheck disable=SC2016
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/common/software/install_claude_code.sh) `

# Source utility functions
# shellcheck source=/dev/null
source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/common/utils/detect_distro.sh)

# Function: install_claude_code_sandbox_deps
# Description: Installs optional sandbox dependencies (bubblewrap, socat) for Claude Code on Linux.
#              Required for sandboxing support. Skip if already present.
install_claude_code_sandbox_deps() {
    local package_manager

    # Skip on non-Linux
    [[ "$(uname)" != "Linux" ]] && return 0

    # Skip if bwrap already available (bubblewrap provides it)
    command -v bwrap &> /dev/null && command -v socat &> /dev/null && return 0

    package_manager=$(get_package_manager 2>/dev/null || echo "unknown")

    echo "🔧 Installing optional sandbox dependencies (bubblewrap, socat) for Claude Code..."

    case "$package_manager" in
        apt)
            sudo apt-get update -qq && sudo apt-get install -y bubblewrap socat 2>/dev/null || true
            ;;
        dnf|yum)
            sudo dnf install -y bubblewrap socat 2>/dev/null || sudo yum install -y bubblewrap socat 2>/dev/null || true
            ;;
        pacman)
            sudo pacman -S --noconfirm bubblewrap socat 2>/dev/null || true
            ;;
        zypper)
            sudo zypper install -y bubblewrap socat 2>/dev/null || true
            ;;
        apk)
            sudo apk add --no-cache bubblewrap socat 2>/dev/null || true
            ;;
        *)
            echo "ℹ️  Unknown package manager ($package_manager), skipping sandbox deps. Claude Code may work without sandboxing."
            return 0
            ;;
    esac

    if command -v bwrap &> /dev/null; then
        echo "✅ Sandbox dependencies installed"
    else
        echo "ℹ️  Sandbox deps could not be installed; Claude Code will run without sandboxing"
    fi
}

# Function: add_claude_code_to_path
# Description: Ensures ~/.local/bin is in PATH for Claude Code. Idempotent.
add_claude_code_to_path() {
    local local_bin="$HOME/.local/bin"
    local shell_rc
    local detected_shell="bash"

    # Skip if claude already in PATH
    if command -v claude &> /dev/null; then
        return 0
    fi

    # Skip if claude not installed in ~/.local/bin
    [[ ! -x "$local_bin/claude" ]] && return 0

    # Detect shell rc
    case "${SHELL:-}" in
        *zsh*)
            detected_shell="zsh"
            ;;
        *bash*)
            detected_shell="bash"
            ;;
        *)
            [[ -f "$HOME/.zshrc" ]] && [[ ! -f "$HOME/.bashrc" ]] && detected_shell="zsh"
            ;;
    esac

    case "$detected_shell" in
        zsh)
            shell_rc="$HOME/.zshrc"
            ;;
        bash|*)
            shell_rc="$HOME/.bashrc"
            ;;
    esac

    # Add to rc if not already present
    if ! grep -q '\.local/bin' "$shell_rc" 2>/dev/null; then
        {
            echo ''
            echo '# Claude Code / user local binaries'
            echo 'export PATH="$HOME/.local/bin:$PATH"'
        } >>"$shell_rc"
        echo "🔧 Added ~/.local/bin to PATH in $shell_rc"
    else
        echo "ℹ️  ~/.local/bin already in PATH (or configured in $shell_rc)"
    fi

    # Apply for current session
    export PATH="$local_bin:$PATH"
}

# Function: install_claude_code
# Description: Installs Claude Code (CLI coding assistant) via native installer.
#              Works on most Linux distros and macOS. Does not require Node.js.
# Reference: https://docs.anthropic.com/en/docs/claude-code/setup
install_claude_code() {
    # Check if already installed
    if command -v claude &> /dev/null; then
        echo "✅ Claude Code is already installed."
        claude --version 2>/dev/null || true
        return 0
    fi

    echo "📦 Installing Claude Code..."

    # macOS and Linux both use the same native installer
    if [[ "$(uname)" == "Darwin" ]] || [[ "$(uname)" == "Linux" ]]; then
        # On Linux, install optional sandbox deps first (install script may not include them)
        if [[ "$(uname)" == "Linux" ]]; then
            install_claude_code_sandbox_deps
        fi

        echo "📥 Running official Claude Code installer..."
        curl -fsSL https://claude.ai/install.sh | bash || {
            echo "❌ Native installer failed. Fallback: install Node.js 18+ and run: npm install -g @anthropic-ai/claude-code"
            return 1
        }

        # Ensure ~/.local/bin is in PATH if the installer didn't handle it
        add_claude_code_to_path
    else
        echo "❌ Unsupported OS: $(uname). Claude Code supports Linux and macOS."
        return 1
    fi

    # Verify installation
    if command -v claude &> /dev/null; then
        echo ""
        echo "✅ Claude Code installed successfully!"
        claude --version 2>/dev/null || echo "   Run 'claude' to start"
        echo ""
        echo "💡 Authenticate via Anthropic Console or Claude Pro/Max subscription"
    else
        add_claude_code_to_path
        if command -v claude &> /dev/null; then
            echo "✅ Claude Code is available after PATH fix."
        else
            echo "❌ Installation may have failed. Ensure ~/.local/bin is in your PATH."
            echo "   Add to your shell rc: export PATH=\"\$HOME/.local/bin:\$PATH\""
            return 1
        fi
    fi
}
