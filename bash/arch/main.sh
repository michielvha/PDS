sudo pacman -S zsh firefox git go nvm 

# Add nvm to profile
source /usr/share/nvm/init-nvm.sh >> ~/.bashrc
source /usr/share/nvm/init-nvm.sh >> ~/.zshrc

sudo pacman -S --needed git base-devel && git clone https://aur.archlinux.org/yay-bin.git && cd yay-bin && makepkg -si

yay cursor-bin

sudo pacman -S docker docker-compose
sudo systemctl enable docker.service
sudo systemctl start docker.service
sudo usermod -aG docker $USER