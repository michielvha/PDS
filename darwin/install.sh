# How i setup my macbook

# Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
echo >> /Users/michielvh/.zprofile\
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> /Users/michielvh/.zprofile\
    eval "$(/opt/homebrew/bin/brew shellenv)"
# Install CLI Homebrew packages
brew install arc warp iterm2


# Install Xcode command line tools
# This is required for Homebrew to work properly
xcode-select --install

# install vscode
brew install --cask visual-studio-code

# Install chatGPT
brew install --cask chatgpt