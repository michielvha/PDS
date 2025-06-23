#!/bin/bash
# Function: set_bashrc_wsl
# Description: Configure bashrc for Windows Subsystem for Linux.

set_bashrc_wsl() {
    echo "🔧 Configuring .bashrc for WSL..."

    # Check if .bashrc already contains the WSL configuration
    if grep -q "# WSL Configuration" ~/.bashrc; then
        echo "⚠️ WSL configuration already exists in .bashrc. Skipping."
        return 0
    fi

    # Append WSL specific configurations to .bashrc
    cat << 'EOF' >> ~/.bashrc

# WSL Configuration
cd /mnt/c/Users/mike/code
EOF

    # Apply changes immediately
    source ~/.bashrc

    echo "✅ .bashrc configured for WSL."
}