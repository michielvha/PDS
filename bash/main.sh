#!/bin/bash

# set locale

# install software

# Configure ZSH

# Function: Create system-wide Crontab to auto update system every night at midnight.
# first check with grep to see if entry doesn't already exist. We use logical || (or) operator to only append if the grep command returns false(1). if it returns true(0) it means the entry already exists and no action will be taken.
function update_system_cron_entry() {
    sudo grep -q "apt update -y && apt upgrade -y" /etc/crontab || \
    echo "0 0 * * * root apt update -y && apt upgrade -y" | sudo tee -a /etc/crontab > /dev/null
}

update_system_cron_entry

# Function: full upgrade with one command

function full_upgrade() {
    sudo apt update -y && sudo apt upgrade -y && sudo apt autoremove -y && sudo apt autoclean -y # && sudo apt dist-upgrade -y
}

full_upgrade