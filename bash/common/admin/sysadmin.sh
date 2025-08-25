#!/bin/bash
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/common/admin/sysadmin.sh) `

# Function: update_system_cron_entry
# Description: Create system-wide Crontab to auto update system every night at midnight.
update_system_cron_entry() {
    # first check with grep to see if entry doesn't already exist. We use logical || (or) operator to only append if the grep command returns false(1). if it returns true(0) it means the entry already exists and no action will be taken.
    sudo grep -q "apt update -y && apt upgrade -y" /etc/crontab || \
    echo "0 0 * * * root apt update -y && apt upgrade -y" | sudo tee -a /etc/crontab > /dev/null
}

# Function: full_upgrade
# Description: Full system upgrade with one command
full_upgrade() {
    sudo apt update -y && sudo apt upgrade -y && sudo apt autoremove -y && sudo apt autoclean -y # && sudo apt dist-upgrade -y
}

# Function: set_sudo_nopasswd_current
# Description: Configure passwordless sudo for the current user
set_sudo_nopasswd_current() {
    # first check with grep to see if entry doesn't already exist. We use logical || (or) operator to only append if the grep command returns false(1). if it returns true(0) it means the entry already exists and no action will be taken.
    sudo grep -q "^$(whoami) ALL=(ALL) NOPASSWD:ALL" /etc/sudoers || echo "$(whoami) ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers > /dev/null
}

# Function: set_sudo_nopasswd
# Description: Configure passwordless sudo for any specified user
# Usage: set_sudo_nopasswd [username]
set_sudo_nopasswd() {
    local user="${1:-$USER}"
    local sudoers_file="/etc/sudoers.d/$user"

    if [[ -z "$user" ]]; then
        echo "Usage: set_sudo_nopasswd [username]"
        return 1
    fi

    if ! id "$user" &>/dev/null; then
        echo "User '$user' does not exist."
        return 2
    fi

    sudo grep -q "$user ALL=(ALL) NOPASSWD:ALL" /etc/sudoers || echo "$user ALL=(ALL) NOPASSWD:ALL" | sudo tee "$sudoers_file" > /dev/null

    sudo chmod 0440 "$sudoers_file"
    echo "Passwordless sudo enabled for $user."
}

# Function: auto_pull_cron_entry
# Description: Auto pull a git repository every minute
# Usage: auto_pull_cron_entry "/path/to/repo"
auto_pull_cron_entry() {
    local repo_path="$1"  # Accepts the repo path as an argument

    if [[ -z "$repo_path" ]]; then
        echo "Error: No repository path provided."
        return 1
    fi

    # Ensure the path is valid
    if [[ ! -d "$repo_path" ]]; then
        echo "Error: Directory '$repo_path' does not exist."
        return 1
    fi

    # Check if the cron job already exists
    sudo grep -q "cd $repo_path && git pull" /etc/crontab || \
    echo "* * * * * $USER cd $repo_path && git pull" | sudo tee -a /etc/crontab > /dev/null
}

# Function: set_fractional_scaling
# Description: Enable fractional scaling for Wayland sessions
set_fractional_scaling() {
    # Check if the system is running Wayland
    if [[ "$XDG_SESSION_TYPE" == "wayland" ]]; then
        gsettings set org.gnome.mutter experimental-features "['scale-monitor-framebuffer']"
    else
        echo "This script is intended for Wayland sessions only."
    fi
}


# Function: restricted_ssh_security_profile
# Description: Enable restricted security profile for SSH
# NIS2 Compliance: Implements cybersecurity risk management measures as required by
#                  EU Directive 2022/2555 (NIS2), specifically:
#                  - Article 21(2)(g): Basic cyber hygiene practices
#                  - Article 21(2)(i): Access control policies and human resources security
# Note: For full NIS2 compliance, consider implementing MFA on top of these settings
# References: https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX:32022L2555
function restricted_ssh_security_profile() {
  # Disable password authentication and root login, enable public key authentication.
  # These configurations reduce attack surface and implement stronger authentication
  # mechanisms aligned with NIS2 cybersecurity requirements for critical infrastructure.
  sudo sed -i -E '
      s/^#?PasswordAuthentication yes/PasswordAuthentication no/
      s/^#?PermitRootLogin prohibit-password/PermitRootLogin no/
      s/^#?PubkeyAuthentication yes/PubkeyAuthentication yes/
  ' /etc/ssh/sshd_config
  echo "🔒 Restricted SSH security profile will be applied on next login."
}