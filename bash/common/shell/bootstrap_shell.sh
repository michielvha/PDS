#!/bin/bash
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/debian/shell/bootstrap_shell.sh) `

# Function: bootstrap_shell
# Description: Setup user and shell environment for Debian-based systems
# TODO: Create bootstrapping function that will perform a complete setup of the shell environment, including user creation, sudoers configuration, and shell enhancements etc.
bootstrap_shell() {
    echo "🔧 Bootstrapping shell environment..."

    # 1. create a new user if it doesn't exist and setup with ssh key
    echo "🔑 Configuring admin user..."
    create_admin

    # 2. Set up sudoers file for the new user
    echo "🔐 Setting up passwordless sudo for $USER_NAME..."
    set_sudo_nopasswd "$USER_NAME"

    echo "✅ Shell environment bootstrapped successfully!"
}