#!/bin/bash
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/common/shell/set_sudo_nopasswd.sh) `

# Function: set_sudo_nopasswd
# Description: Setup passwordless sudo for a user
# Usage: set_sudo_nopasswd <username>
set_sudo_nopasswd() {
    local user="$1"
    local sudoers_file="/etc/sudoers.d/$user"

    if [[ -z "$user" ]]; then
        echo "Usage: set_sudo_nopasswd <username>"
        return 1
    fi

    if ! id "$user" &>/dev/null; then
        echo "User '$user' does not exist."
        return 2
    fi

    echo "$user ALL=(ALL) NOPASSWD: ALL" | sudo tee "$sudoers_file" > /dev/null

    sudo chmod 0440 "$sudoers_file"
    echo "Passwordless sudo enabled for $user."
}