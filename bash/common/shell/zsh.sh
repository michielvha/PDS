#!/bin/bash
# Common shell configuration functions
# This module contains functions for setting up and configuring ZSH shell environments
# Usage: source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/common/shell/zsh.sh)

# Function: install_zi
# Description: Installs and configures Zi, a package manager for ZSH
install_zi() {
    # Check if git is installed
    if ! command -v git &> /dev/null; then
        read -p "Git is not installed. Install it now? (y/n): " choice
        [[ "$choice" =~ ^[Yy]$ ]] || { echo "Git is required. Exiting."; return 1; }

        sudo apt update -y && sudo apt install -y git || { echo "Failed to install Git. Install it manually."; return 1; }
    fi

    # Install Zi
    sudo mkdir -p /usr/local/share/zi ~/.config/zi
    sudo git clone --depth=1 https://github.com/z-shell/zi /usr/local/share/zi
    echo "Zi installed successfully."
}

# Function: configure_zsh
# Description: Configures ZSH using Zi with plugins and settings for an enhanced shell experience
configure_zsh() {
  cat <<EOF | sudo tee /etc/zshrc
source /usr/local/share/zi/zi.zsh

# --- Theme stuff ---
# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

zi light romkatv/powerlevel10k

[[ ! -f ~/.p10k.zsh ]] || ~/.p10k.zsh #import p10k config

### --- Plugins ---
zi light zsh-users/zsh-syntax-highlighting
zi light zsh-users/zsh-autosuggestions
zi light zsh-users/zsh-history-substring-search
zi light agkozak/zsh-z

# Installs stuff in ~/zi/plugins that needs to be manually sourced.
zi light ohmyzsh/ohmyzsh
zi snippet OMZP::docker
zi snippet OMZP::history
source "$HOME/.zi/plugins/ohmyzsh---ohmyzsh/plugins/git/git.plugin.zsh"

zi light marlonrichert/zsh-autocomplete
zstyle ':autocomplete:*' default-context history-incremental-search-backward
zstyle ':autocomplete:*' min-input 1
setopt HIST_FIND_NO_DUPS

# --- Enable kubectl autocompletion for zsh ---
#autoload -Uz compinit && compinit # zi enables this automatically.
source <(kubectl completion zsh)

# alias + auto complete for alias
alias k='kubectl'
compdef __start_kubectl k

# --- Various ---
neofetch
alias knr='kubectl get pods --field-selector=status.phase!=Running'
EOF

  # this configures zsh for all new users, first create this config then create the new user. Point it to global config.
  cat <<EOF | sudo tee /etc/skel/.zshrc
source /etc/zshrc
EOF
}

# Function: set_default_zsh
# Description: Sets ZSH as the default shell for the current user
set_default_zsh() {
    sudo chsh -s "$(which zsh)" "$(whoami)"
}