#!/bin/bash
# purpose:  This module contains functions used in system administration.
# usage: quickly source this module with the following command:
# ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/module/sysadmin.sh) `
# ------------------------------------------------------------------------------------------------------------------------------------------------
# Create system-wide Crontab to auto update system every night at midnight.
update_system_cron_entry() {
    # first check with grep to see if entry doesn't already exist. We use logical || (or) operator to only append if the grep command returns false(1). if it returns true(0) it means the entry already exists and no action will be taken.
    sudo grep -q "apt update -y && apt upgrade -y" /etc/crontab || \
    echo "0 0 * * * root apt update -y && apt upgrade -y" | sudo tee -a /etc/crontab > /dev/null
}

# ------------------------------------------------------------------------------------------------------------------------------------------------
# full upgrade with one command
full_upgrade() {
    sudo apt update -y && sudo apt upgrade -y && sudo apt autoremove -y && sudo apt autoclean -y # && sudo apt dist-upgrade -y
}

# ------------------------------------------------------------------------------------------------------------------------------------------------
# configure passwordless sudo for the current user
set_pwless_sudo() {
    # first check with grep to see if entry doesn't already exist. We use logical || (or) operator to only append if the grep command returns false(1). if it returns true(0) it means the entry already exists and no action will be taken.
    sudo grep -q "^$(whoami) ALL=(ALL) NOPASSWD:ALL" /etc/sudoers || echo "$(whoami) ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers > /dev/null
}

# auto pull a git repository every minute
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
    echo "* * * * * root cd $repo_path && git pull" | sudo tee -a /etc/crontab > /dev/null
}

# Usage
# auto_pull_cron_entry "/path/to/repo"
