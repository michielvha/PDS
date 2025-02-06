#!/bin/bash
# ------------------------------------------------------------------------------------------------------------------------------------------------
# Function: Install & Configure ZSH
function install_zsh() {
    # install dependencies
    sudo apt install zsh git curl -y
    # Set the default shell to zsh
    sudo chsh -s $(which zsh) $(whoami)
    # Install oh-my-zsh: https://ohmyz.sh
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
}

function configure_zsh() {
    # Install Powerlevel10k: https://github.com/romkatv/powerlevel10k
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

    if grep -q '^ZSH_THEME=' ~/.zshrc; then
        # Replace the existing line
        sudo sed -i 's|^ZSH_THEME=.*|ZSH_THEME="powerlevel10k/powerlevel10k"|' ~/.zshrc
    else
        # Add the line if it doesn't exist
        echo 'ZSH_THEME="powerlevel10k/powerlevel10k"' | sudo tee -a ~/.zshrc > /dev/null
    fi

    # Install extra plugins, if not installed you cannot add zsh-syntax-highlighting and zsh-autosuggestions to plugins.
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

    # Enable Extensions: https://github.com/ohmyzsh/ohmyzsh/wiki/Plugins
    # Define the list of plugins
    PLUGINS_LIST="git history z docker zsh-syntax-highlighting zsh-autosuggestions"
    # Update PLUGINS in ~/.zshrc
    if grep -q '^plugins=' ~/.zshrc; then
        # Replace the existing plugins line
        sudo sed -i "s|^plugins=.*|plugins=($PLUGINS_LIST)|" ~/.zshrc
    else
        # Add the plugins line if it doesn't exist
        echo "plugins=($PLUGINS_LIST)" | sudo tee -a ~/.zshrc > /dev/null
    fi

    # TODO: find some way to automate the configuration of powerlevel10k by copying the .p10k.zsh file from the repo to the home directory
    # seems like you can't just copy the config file, you have to run the p10k configure command
    source ~/.zshrc
}

# ------------------------------------------------------------------------------------------------------------------------------------------------
# Function: Create system-wide Crontab to auto update system every night at midnight.
# first check with grep to see if entry doesn't already exist. We use logical || (or) operator to only append if the grep command returns false(1). if it returns true(0) it means the entry already exists and no action will be taken.
function update_system_cron_entry() {
    sudo grep -q "apt update -y && apt upgrade -y" /etc/crontab || \
    echo "0 0 * * * root apt update -y && apt upgrade -y" | sudo tee -a /etc/crontab > /dev/null
}

# ------------------------------------------------------------------------------------------------------------------------------------------------
# Function: full upgrade with one command
function full_upgrade() {
    sudo apt update -y && sudo apt upgrade -y && sudo apt autoremove -y && sudo apt autoclean -y # && sudo apt dist-upgrade -y
}

# ------------------------------------------------------------------------------------------------------------------------------------------------
# Function: full upgrade with one command
function install_awscli() {

    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install

    # Detect the shell and update the respective config file with path addition
#    case "$0" in
#        *zsh) echo 'export PATH=$PATH:/usr/local/bin/' >> ~/.zshrc ;;
#        *bash) echo 'export PATH=$PATH:/usr/local/bin/' >> ~/.bashrc ;;
#        *) echo "Unknown shell: $0. Please add AWS CLI path manually." ;;
#    esac

    # Clean up
    rm -rf awscliv2.zip aws/

    # Verify AWS CLI installation
    aws --version
}