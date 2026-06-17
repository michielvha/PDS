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

    # Stage the entry in a temp file and validate it with `visudo -c` BEFORE
    # installing. A malformed sudoers file can lock you out of sudo entirely,
    # so we never write directly to /etc/sudoers.d/.
    local tmp
    tmp="$(mktemp)"
    printf '%s ALL=(ALL) NOPASSWD: ALL\n' "$user" > "$tmp"

    if ! sudo visudo -cf "$tmp" >/dev/null; then
        echo "Refusing to install: sudoers validation failed for '$sudoers_file'."
        rm -f "$tmp"
        return 3
    fi

    # install(1) places it atomically with the correct owner/perms (0440).
    sudo install -m 0440 -o root -g root "$tmp" "$sudoers_file"
    rm -f "$tmp"
    echo "Passwordless sudo enabled for $user."
}