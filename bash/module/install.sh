#!/bin/bash
# Purpose: This module contains functions used for installing various tools / software.
# Usage: quickly source this module with the following command:
# ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/module/install.sh) ` 
# ------------------------------------------------------------------------------------------------------------------------------------------------
# Function: full upgrade with one command
# tested: ✅
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
# Currently only supports ubuntu using either zsh & bash
# tested: ⚠️
function install_kubectl() {
    local VERSION="${1:-1.32}"
    # ✅
    sudo apt update -y
    sudo apt install -y apt-transport-https ca-certificates curl gnupg
    sudo mkdir -p -m 755 /etc/apt/keyrings
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v$VERSION/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg # allow unprivileged APT programs to read this keyring
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v$VERSION/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
    sudo chmod 644 /etc/apt/sources.list.d/kubernetes.list   # helps tools such as command-not-found to work correctly
    sudo apt update
    sudo apt install -y kubectl
    
    # auto completion configuration ⚠️
    # Detect shell and set file to update
    SHELL_NAME=$(basename "$SHELL")
    [[ "$SHELL_NAME" == "zsh" ]] && PROFILE_FILE="$HOME/.zshrc" || PROFILE_FILE="$HOME/.bashrc"

    # Ensure autocompletion is set
    grep -qxF "source <(kubectl completion $SHELL_NAME)" "$PROFILE_FILE" || echo "source <(kubectl completion $SHELL_NAME)" >> "$PROFILE_FILE"

    # Ensure alias 'k=kubectl' is set
    grep -qxF "alias k=kubectl" "$PROFILE_FILE" || echo "alias k=kubectl" >> "$PROFILE_FILE"

    # Ensure completion for alias 'k'
    if [[ "$SHELL_NAME" == "zsh" ]]; then
        grep -qxF "compdef __start_kubectl k" "$PROFILE_FILE" || echo "compdef __start_kubectl k" >> "$PROFILE_FILE"
    else
        grep -qxF "complete -F __start_kubectl k" "$PROFILE_FILE" || echo "complete -F __start_kubectl k" >> "$PROFILE_FILE"
    fi

    # install krew (kubectl plugin manager) ✅
    (
    set -x; cd "$(mktemp -d)" &&
    OS="$(uname | tr '[:upper:]' '[:lower:]')" &&
    ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" &&
    KREW="krew-${OS}_${ARCH}" &&
    curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" &&
    tar zxvf "${KREW}.tar.gz" &&
    ./"${KREW}" install krew
    )
    # Ensure binary is added to $PATH
    grep -qxF 'export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"' "$PROFILE_FILE" || echo 'export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"' >> "$PROFILE_FILE"

    # apply changes
    source $PROFILE_FILE

    # install kubectl plugins
    kubectl krew update
    # view secrets
    kubectl krew install view-secret
    # stern
    kubectl krew install stern

    # source $PROFILE_FILE
    echo "Installation complete. "  # Restart your terminal or run 'source $PROFILE_FILE' to apply changes.
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

set_default_zsh() {
    # Set the default shell to zsh
    sudo chsh -s $(which zsh) $(whoami)
}