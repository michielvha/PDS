# My macbook setup

# Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
echo >> /Users/michielvh/.zprofile\
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> /Users/michielvh/.zprofile\
    eval "$(/opt/homebrew/bin/brew shellenv)"

# Install Xcode command line tools
# This is required for Homebrew to work properly
xcode-select --install

# Install CLI Homebrew packages
brew install arc \
     warp \
     iterm2 \
     gh \
     go \
     neofetch \
     kubectl \
     helm \
     kustomize


# Install GUI Homebrew packages
# make sure the font is installed: https://github.com/romkatv/powerlevel10k?tab=readme-ov-file#manual-font-installation
brew install --cask visual-studio-code \
     chatgpt

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
}

setup_zsh (){
    # Install zsh
    brew install zsh

    # Set zsh as default shell
    chsh -s $(which zsh)

    # Install zi
    install_zi

    # Configure zsh
    configure_zsh
}