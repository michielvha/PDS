# Purpose: This module contains functions used for installing various tools / software on macOS.
# Usage: quickly source this module with the following command:
# ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/darwin/functions.sh) ` 
# ------------------------------------------------------------------------------------------------------------------------------------------------

# ZSH setup
install_zi (){
    sh -c "$(curl -fsSL https://git.io/zi-install)"
}

configure_zsh (){
    cat <<EOF | sudo tee ~/.zshrc
source ~/.zi/bin/zi.zsh
zi light romkatv/powerlevel10k

### --- Plugins ---
zi light zsh-users/zsh-syntax-highlighting
zi light zsh-users/zsh-autosuggestions
zi light zsh-users/zsh-history-substring-search
zi light agkozak/zsh-z

# Installs stuff in ~/zi/plugins that needs to be manually sourced.
zi snippet OMZP::docker
zi snippet OMZP::history

zi light marlonrichert/zsh-autocomplete
zstyle ':autocomplete:*' default-context history-incremental-search-backward
zstyle ':autocomplete:*' min-input 1
setopt HIST_FIND_NO_DUPS

# --- Enable kubectl autocompletion for zsh ---
autoload -Uz compinit
compinit
source <(kubectl completion zsh)

# alias + auto complete for alias
alias k='kubectl'
compdef __start_kubectl k

# --- Various ---
neofetch
alias knr='kubectl get pods --field-selector=status.phase!=Running'
EOF
}

setup_zsh (){
    # Install zsh, included by default in macOS
    # brew install zsh@$VERSION

    # Install zi
    install_zi

    # Configure zsh
    configure_zsh
}

# add go to path
setup_go_env (){
    # Setup go env
    echo 'export GOPATH=$HOME/go' >> ~/.zshrc
    echo 'export PATH=$PATH:$GOPATH/bin' >> ~/.zshrc
    echo 'export PATH=$GOBIN:/usr/local/go/bin:$PATH' >> ~/.zshrc
    source ~/.zshrc
}