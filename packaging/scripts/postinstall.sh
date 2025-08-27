#!/bin/bash
# PDS Post-installation script
# TODO: update this to match current implementation
set -e

echo "========================================"
echo "PDS (Personal Development Scripts) v1.0.0"
echo "========================================"
echo
echo "✅ PDS functions have been installed successfully!"
echo
echo "📂 Functions are available in:"
echo "   • Software installation: /usr/share/pds/software/"
echo "   • UI/Theme setup: /usr/share/pds/ui/"
echo "   • Deployment: /usr/share/pds/deploy/"
echo
echo "🔧 Usage:"
echo "   • Open a new shell to auto-load functions"
echo "   • Or run: source /usr/share/pds/init.sh"
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
