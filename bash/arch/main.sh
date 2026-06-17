#!/bin/bash

sudo pacman -Syu --needed --noconfirm openssh zsh firefox ghostty konsole git go nvm net-tools bat btop fastfetch yq make docker docker-compose github-cli bind

# passwordless sudo for the current user
source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/common/shell/set_sudo_nopasswd.sh)
set_sudo_nopasswd "$USER"

# add go to profile
grep -q 'go/bin' ~/.bashrc 2>/dev/null || echo 'export PATH="$PATH:$HOME/go/bin"' >> ~/.bashrc
grep -q 'go/bin' ~/.zshrc  2>/dev/null || echo 'export PATH="$PATH:$HOME/go/bin"' >> ~/.zshrc

# Add nvm to profile
grep -q 'init-nvm.sh' ~/.bashrc 2>/dev/null || echo 'source /usr/share/nvm/init-nvm.sh' >> ~/.bashrc
grep -q 'init-nvm.sh' ~/.zshrc  2>/dev/null || echo 'source /usr/share/nvm/init-nvm.sh' >> ~/.zshrc

# enable docker
sudo systemctl enable docker.service
sudo systemctl start docker.service
sudo usermod -aG docker $USER

# Install yay (AUR helper)
command -v yay >/dev/null 2>&1 || {
  sudo pacman -S --needed --noconfirm git base-devel
  tmpdir=$(mktemp -d)
  git clone https://aur.archlinux.org/yay-bin.git "$tmpdir/yay-bin"
  ( cd "$tmpdir/yay-bin" && makepkg -si --noconfirm )
}

yay -S --noconfirm cursor-bin

# Enable and start sshd
sudo systemctl start sshd
sudo systemctl enable sshd
