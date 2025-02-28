#!/bin/bash

# The functions in this module serve as helper function to other modules.

# ------------------------------------------------------------------------------------------------------------------------------------------------
# Function: Install & Configure OhMyZSH
function install_ohmyzsh() {
    # install dependencies
    sudo apt install zsh git curl -y
    # Set the default shell to zsh
    sudo chsh -s $(which zsh) $(whoami)
    # Install oh-my-zsh: https://ohmyz.sh
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
}

function configure_ohmyzsh() {
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

function install_zsh_extensions() {
    # raw install no package manager
    # Install zsh-syntax-highlighting
    git clone https://github.com/zsh-users/zsh-autosuggestions ~/.zsh/zsh-autosuggestions
    echo "source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh" >> ~/.zshrc

    # git clone https://github.com/zsh-users/fast-syntax-highlighting.git ~/.zsh/fast-syntax-highlighting
    # TODO: Promote this to main configure function
    git clone https://github.com/marlonrichert/zsh-autocomplete.git ~/.zsh/zsh-autocomplete
    cat <<EOF | sudo tee -a ~/.zshrc > /dev/null

        # Enable history substring search (like PSReadLine)
        if [ -f ~/.zsh/zsh-autocomplete/zsh-autocomplete.plugin.zsh ]; then
            zstyle ':autocomplete:*' default-context history-incremental-search-backward
            zstyle ':autocomplete:*' min-input 1
            setopt HIST_FIND_NO_DUPS
            source ~/.zsh/zsh-autocomplete/zsh-autocomplete.plugin.zsh


        fi
EOF


    git clone https://github.com/zsh-users/zsh-history-substring-search.git ~/.zsh/zsh-history-substring-search

    cat <<EOF | sudo tee -a ~/.zshrc > /dev/null
    # Enable history substring search (like PSReadLine)
    if [ -f ~/.zsh/zsh-history-substring-search/zsh-history-substring-search.zsh ]; then
        source ~/.zsh/zsh-history-substring-search/zsh-history-substring-search.zsh

        # Set keybindings to navigate like PSReadLine
        bindkey '^[[A' history-substring-search-up    # Up Arrow for previous matching command
        bindkey '^[[B' history-substring-search-down  # Down Arrow for next matching command
        bindkey "${terminfo[kcuu1]}" history-substring-search-up
        bindkey "${terminfo[kcud1]}" history-substring-search-down

    fi

    export HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_FOUND='fg=cyan,bold'
    export HISTORY_SUBSTRING_SEARCH_HIGHLIGHT_NOT_FOUND='fg=red'

EOF

# enable persistent History
## Persistent Zsh History Settings
#export HISTFILE="$HOME/.zsh_history"    # File to store history
#export HISTSIZE=100000                  # Max lines kept in memory
#export SAVEHIST=100000                   # Max lines stored in $HISTFILE
#setopt INC_APPEND_HISTORY                # Save each command as you enter it
#setopt SHARE_HISTORY                     # Share history across multiple sessions
#setopt HIST_IGNORE_ALL_DUPS              # Remove duplicate entries
#setopt HIST_REDUCE_BLANKS                # Trim unnecessary spaces
#setopt HIST_SAVE_NO_DUPS                 # Don't save duplicate commands
#setopt HIST_VERIFY                       # Let you edit before running history commands
#setopt HIST_IGNORE_SPACE                 # Ignore commands that start with a space

}




