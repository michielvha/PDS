#!/bin/bash

# set locale

# install software

# ------------------------------------------------------------------------------------------------------------------------------------------------

# Configure ZSH
function Install_ZSH() {
# Set the default shell to zsh
sudo chsh -s $(which zsh) $(whoami)
# Install oh-my-zsh: https://ohmyz.sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
# Install Powerlevel10k: https://github.com/romkatv/powerlevel10k
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

sudo grep -q "ZSH_THEME="powerlevel10k/powerlevel10k"" ~/.zshrc || \
echo "ZSH_THEME="powerlevel10k/powerlevel10k"" | sudo tee -a ~/.zshrc > /dev/null
# find some way to automate the configuration of powerlevel10k by copying the .p10k.zsh file from the repo to the home directory
}

# ------------------------------------------------------------------------------------------------------------------------------------------------

# Function: Create system-wide Crontab to auto update system every night at midnight.
# first check with grep to see if entry doesn't already exist. We use logical || (or) operator to only append if the grep command returns false(1). if it returns true(0) it means the entry already exists and no action will be taken.
function update_system_cron_entry() {
    sudo grep -q "apt update -y && apt upgrade -y" /etc/crontab || \
    echo "0 0 * * * root apt update -y && apt upgrade -y" | sudo tee -a /etc/crontab > /dev/null
}

update_system_cron_entry

# ------------------------------------------------------------------------------------------------------------------------------------------------

# Function: full upgrade with one command

function full_upgrade() {
    sudo apt update -y && sudo apt upgrade -y && sudo apt autoremove -y && sudo apt autoclean -y # && sudo apt dist-upgrade -y
}

full_upgrade