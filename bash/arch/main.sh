#!/bin/bash

sudo pacman -S openssh zsh firefox git go nvm net-tools bat btop fastfetch yq make docker docker-compose github-cli
sudo pacman -Syu

# Add nvm to profile
source /usr/share/nvm/init-nvm.sh >> ~/.bashrc
source /usr/share/nvm/init-nvm.sh >> ~/.zshrc

# enable docker
sudo systemctl enable docker.service
sudo systemctl start docker.service
sudo usermod -aG docker $USER

# Install yay (AUR helper)
sudo pacman -S --needed git base-devel && git clone https://aur.archlinux.org/yay-bin.git && cd yay-bin && makepkg -si

yay cursor-bin

# Enable and start sshd
sudo systemctl start sshd
sudo systemctl enable sshd