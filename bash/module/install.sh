#!/bin/bash

# This module contains functions used for installing various tools / software.

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

# ------------------------------------------------------------------------------------------------------------------------------------------------
# Function: Install kubernetes on debian based systems
function install_kubectl() {
    sudo apt update -y
    sudo apt install -y apt-transport-https ca-certificates curl gnupg
    sudo mkdir -p -m 755 /etc/apt/keyrings
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg # allow unprivileged APT programs to read this keyring
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
    sudo chmod 644 /etc/apt/sources.list.d/kubernetes.list   # helps tools such as command-not-found to work correctly
    sudo apt update
    sudo apt install -y kubectl
}

# ------------------------------------------------------------------------------------------------------------------------------------------------
# Function: Install azure cli on any supported linux system
function install_azcli() {
  # quick and easy script maintained by microsoft. Do not use in production.
  curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
}

function install_azcli_safe() {
  sudo apt-get update -y
  sudo apt-get install apt-transport-https ca-certificates curl gnupg lsb-release -y

  sudo mkdir -p /etc/apt/keyrings
  curl -sLS https://packages.microsoft.com/keys/microsoft.asc |
    gpg --dearmor | sudo tee /etc/apt/keyrings/microsoft.gpg > /dev/null
  sudo chmod go+r /etc/apt/keyrings/microsoft.gpg

  AZ_DIST=$(lsb_release -cs)
  echo "Types: deb
  URIs: https://packages.microsoft.com/repos/azure-cli/
  Suites: ${AZ_DIST}
  Components: main
  Architectures: $(dpkg --print-architecture)
  Signed-by: /etc/apt/keyrings/microsoft.gpg" | sudo tee /etc/apt/sources.list.d/azure-cli.sources

  sudo apt update -y
  sudo apt install azure-cli -y
}

# ------------------------------------------------------------------------------------------------------------------------------------------------
# Function: Install & Configure Zi
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
# --- Enable kubectl autocompletion ---
autoload -Uz compinit && compinit
source <(kubectl completion zsh)

# Alias for kubectl
alias k='kubectl'

# Enable completion for alias 'k'
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

set_default_zsh() {
    # Set the default shell to zsh
    sudo chsh -s $(which zsh) $(whoami)
}