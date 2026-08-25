#!/bin/bash
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/common/shell/bootstrap_shell.sh) `

# Function: bootstrap_shell
# Description: Creates an admin user with SSH access and grants it passwordless sudo. This is the
#              server-side counterpart to bootstrap_workstation; for a personal dev machine use
#              `bootstrap_workstation base` instead.
# Usage: bootstrap_shell <username>
bootstrap_shell() {
    local user_name="$1"

    [[ -z "$user_name" ]] && { echo "Usage: bootstrap_shell <username>"; return 1; }

    echo "🔧 Bootstrapping shell environment for $user_name..."

    # shellcheck disable=SC1090
    source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/common/shell/create_admin.sh) \
        || { echo "❌ Failed to load create_admin.sh"; return 1; }
    # shellcheck disable=SC1090
    source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/common/shell/set_sudo_nopasswd.sh) \
        || { echo "❌ Failed to load set_sudo_nopasswd.sh"; return 1; }

    # 1. create the user if it doesn't exist and seed its authorized_keys
    echo "🔑 Configuring admin user..."
    configure_admin "$user_name" || return 1

    # 2. Set up sudoers file for the new user
    echo "🔐 Setting up passwordless sudo for $user_name..."
    set_sudo_nopasswd "$user_name" || return 1

    echo "✅ Shell environment bootstrapped successfully!"
}
