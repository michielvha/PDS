# import required functions from PDS github repository
source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/darwin/functions.sh)

# Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
echo >> $HOME/.zprofile\
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> $HOME/.zprofile\
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
     kustomize \
     blackhole-2ch \
     gitversion \
     goreleaser
# Install GUI Homebrew packages
# make sure the font is installed: https://github.com/romkatv/powerlevel10k?tab=readme-ov-file#manual-font-installation
brew tap microsoft/git

brew install --cask visual-studio-code \
     chatgpt \
     tailscale \
     microsoft-teams \
     obs \
     zen-browser \
     lens \
     git-credential-manager-core

setup_zsh

setup_go_env
