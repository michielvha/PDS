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