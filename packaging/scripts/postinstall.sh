#!/bin/bash
# PDS Post-installation script
set -e

echo "========================================"
echo "PDS (Personal Development Scripts)"
echo "========================================"
echo

# Source the PDS init script for interactive shells
PDS_INIT_SOURCE='# PDS auto-loading (added by pds package)
if [ -r /usr/share/pds/init.sh ] && [ -z "${PDS_DISABLE:-}" ]; then
    . /usr/share/pds/init.sh 2>/dev/null || true
fi
# End of PDS auto-loading'

# Add to /etc/zsh/zshrc if zsh is available
if [ -f /etc/zsh/zshrc ]; then
    if ! grep -q "# PDS auto-loading" /etc/zsh/zshrc 2>/dev/null; then
        echo "" >> /etc/zsh/zshrc
        echo "$PDS_INIT_SOURCE" >> /etc/zsh/zshrc
        echo "✅ Added PDS auto-loading to /etc/zsh/zshrc"
    else
        echo "ℹ️  PDS auto-loading already configured in /etc/zsh/zshrc"
    fi
fi

# Add to /etc/bash.bashrc if bash is available
if [ -f /etc/bash.bashrc ]; then
    if ! grep -q "# PDS auto-loading" /etc/bash.bashrc 2>/dev/null; then
        # Append at the end (after the interactive check, bash.bashrc handles that)
        echo "" >> /etc/bash.bashrc
        echo "$PDS_INIT_SOURCE" >> /etc/bash.bashrc
        echo "✅ Added PDS auto-loading to /etc/bash.bashrc"
    else
        echo "ℹ️  PDS auto-loading already configured in /etc/bash.bashrc"
    fi
fi

echo
echo "✅ PDS functions have been installed successfully!"
echo
echo "📂 Functions are available in:"
echo "   • Common functions: /usr/share/pds/common/"
echo "   • Debian-specific: /usr/share/pds/debian/"
echo
echo "🔧 Usage:"
echo "   • Open a new shell to auto-load functions"
echo "   • Or run: . /usr/share/pds/init.sh"
echo "   • Use 'pds help' to see available commands"
echo "   • Use 'pds list' to see all functions"
echo
echo "💡 Examples:"
echo "   • install_docker       # Install Docker"
echo "   • install_vscode       # Install VS Code"
echo "   • install_packer       # Install HashiCorp Packer"
echo "   • pds search docker    # Find Docker-related functions"
echo
echo "🚫 To disable auto-loading: export PDS_DISABLE=1"
echo
echo "📖 Documentation: https://github.com/michielvha/PDS"
echo "========================================"
