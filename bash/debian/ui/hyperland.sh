#!/bin/bash
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/debian/ui/hyperland.sh) `

# Color codes
C_BLUE='\033[0;34m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_CYAN='\033[0;36m'
C_RED='\033[0;31m'
C_RESET='\033[0m'

# Function: install_hyprland
# Description: Installs Hyprland Wayland compositor and common dependencies on Ubuntu-based systems
install_hyprland() {
	echo -e "${C_BLUE}[*]${C_RESET} Installing Hyprland Wayland compositor..."

	# Try PPA installation first (simpler and more reliable)
	echo -e "${C_BLUE}[*]${C_RESET} Adding Hyprland PPA..."
	if sudo add-apt-repository -y ppa:cppiber/hyprland 2>/dev/null; then
		echo -e "${C_BLUE}[*]${C_RESET} Updating package lists..."
		sudo apt update || { 
			echo -e "${C_RED}[-]${C_RESET} Failed to update package lists"
			return 1
		}

		echo -e "${C_BLUE}[*]${C_RESET} Installing Hyprland from PPA..."
		if sudo apt install -y hyprland; then
			echo -e "${C_GREEN}[+]${C_RESET} Hyprland installed from PPA"
		else
			echo -e "${C_YELLOW}[!]${C_RESET} PPA installation failed, falling back to source build..."
			# Remove PPA if installation failed
			sudo add-apt-repository -y -r ppa:cppiber/hyprland 2>/dev/null
			sudo apt update
		fi
	fi

	# If PPA method didn't work or wasn't available, build from source
	if ! command -v Hyprland &> /dev/null && ! command -v hyprland &> /dev/null; then
		echo -e "${C_BLUE}[*]${C_RESET} Building Hyprland from source..."
		
		# Update package lists
		echo -e "${C_BLUE}[*]${C_RESET} Updating package lists..."
		sudo apt update || { 
			echo -e "${C_RED}[-]${C_RESET} Failed to update package lists"
			return 1
		}

		# Install build dependencies
		echo -e "${C_BLUE}[*]${C_RESET} Installing build dependencies..."
		sudo apt install -y \
			build-essential \
			git \
			cmake \
			ninja-build \
			meson \
			gettext \
			libfontconfig-dev \
			libfreetype6-dev \
			libx11-dev \
			libx11-xcb-dev \
			libxcb-res0-dev \
			libxcb-cursor-dev \
			libxcb-ewmh-dev \
			libxcb-icccm4-dev \
			libxcb-image0-dev \
			libxcb-randr0-dev \
			libxcb-render0-dev \
			libxcb-render-util0-dev \
			libxcb-shm0-dev \
			libxcb-util-dev \
			libxcb-xfixes0-dev \
			libxcb-xinerama0-dev \
			libxcb-xkb-dev \
			libxkbcommon-dev \
			libxkbcommon-x11-dev \
			libxcb-xtest0-dev \
			libxcb-xrm-dev \
			libpixman-1-dev \
			libcairo2-dev \
			libpango1.0-dev \
			libpangocairo-1.0-0 \
			libgdk-pixbuf2.0-dev \
			libgl1-mesa-dev \
			libglu1-mesa-dev \
			libxext-dev \
			libxcomposite-dev \
			libxdamage-dev \
			libxfixes-dev \
			libxrender-dev \
			libxrandr-dev \
			libxinerama-dev \
			libxpresent-dev \
			libxss-dev \
			libglfw3-dev \
			libwayland-dev \
			wayland-protocols \
			libinput-dev \
			libudev-dev \
			libseat-dev \
			seatd \
			|| { 
				echo -e "${C_RED}[-]${C_RESET} Failed to install build dependencies"
				return 1
			}

		# Build wlroots with wrap downloads enabled
		echo -e "${C_BLUE}[*]${C_RESET} Building wlroots..."
		tmp_dir=$(mktemp -d)
		cd "$tmp_dir" || { 
			echo -e "${C_RED}[-]${C_RESET} Failed to create temp directory"
			return 1
		}

		git clone --recursive https://gitlab.freedesktop.org/wlroots/wlroots.git || { 
			echo -e "${C_RED}[-]${C_RESET} Failed to clone wlroots repository"
			rm -rf "$tmp_dir"
			return 1
		}

		cd wlroots || { 
			echo -e "${C_RED}[-]${C_RESET} Failed to enter wlroots directory"
			rm -rf "$tmp_dir"
			return 1
		}

		# Enable wrap downloads to handle dependency version issues
		meson setup build/ --prefix=/usr --wrap-mode=forcefallback || { 
			echo -e "${C_RED}[-]${C_RESET} Failed to setup wlroots build"
			cd - > /dev/null || true
			rm -rf "$tmp_dir"
			return 1
		}

		ninja -C build/ || { 
			echo -e "${C_RED}[-]${C_RESET} Failed to build wlroots"
			cd - > /dev/null || true
			rm -rf "$tmp_dir"
			return 1
		}

		sudo ninja -C build/ install || { 
			echo -e "${C_RED}[-]${C_RESET} Failed to install wlroots"
			cd - > /dev/null || true
			rm -rf "$tmp_dir"
			return 1
		}

		cd "$tmp_dir" || { 
			echo -e "${C_RED}[-]${C_RESET} Failed to return to temp directory"
			rm -rf "$tmp_dir"
			return 1
		}

		# Build and install Hyprland
		echo -e "${C_BLUE}[*]${C_RESET} Building Hyprland..."
		git clone --recursive https://github.com/hyprwm/Hyprland.git || { 
			echo -e "${C_RED}[-]${C_RESET} Failed to clone Hyprland repository"
			rm -rf "$tmp_dir"
			return 1
		}

		cd Hyprland || { 
			echo -e "${C_RED}[-]${C_RESET} Failed to enter Hyprland directory"
			rm -rf "$tmp_dir"
			return 1
		}

		make all || { 
			echo -e "${C_RED}[-]${C_RESET} Failed to build Hyprland"
			cd - > /dev/null || true
			rm -rf "$tmp_dir"
			return 1
		}

		sudo make install || { 
			echo -e "${C_RED}[-]${C_RESET} Failed to install Hyprland"
			cd - > /dev/null || true
			rm -rf "$tmp_dir"
			return 1
		}

		cd - > /dev/null || true
		rm -rf "$tmp_dir"
	fi

	# Install common dependencies
	echo -e "${C_BLUE}[*]${C_RESET} Installing common dependencies..."
	sudo apt install -y \
		kitty \
		rofi \
		waybar \
		dunst \
		grim \
		slurp \
		brightnessctl \
		pamixer \
		playerctl \
		wl-clipboard \
		python3-pip \
		2>/dev/null || echo -e "${C_YELLOW}[!]${C_RESET} Some optional packages could not be installed"

	# Try to install optional packages
	for pkg in swaync fastfetch swappy cliphist; do
		sudo apt install -y "$pkg" 2>/dev/null || echo -e "${C_YELLOW}[!]${C_RESET} Package $pkg not available (optional)"
	done

	# Verify installation
	if command -v Hyprland &> /dev/null || command -v hyprland &> /dev/null; then
		echo -e "${C_GREEN}[+]${C_RESET} Hyprland installed successfully!"
		echo -e "${C_CYAN}[i]${C_RESET} Log out and select Hyprland as your session from your login manager (GDM/SDDM/LightDM)"
		return 0
	else
		echo -e "${C_RED}[-]${C_RESET} Hyprland installation failed - binary not found in PATH"
		return 1
	fi
}

# Function: rice
# Description: Installs the Hyprland rice configuration from shell-ninja/hyprconf-v2
rice() {
	echo -e "${C_BLUE}[*]${C_RESET} Installing Hyprland rice configuration..."

	# Check if Hyprland is installed
	if ! command -v hyprland &> /dev/null; then
		echo -e "${C_YELLOW}[!]${C_RESET} Hyprland is not installed. Please run install_hyprland first."
		return 1
	fi

	# Clone the repository
	tmp_dir=$(mktemp -d)
	echo -e "${C_BLUE}[*]${C_RESET} Cloning hyprconf-v2 repository..."
	git clone --depth=1 https://github.com/shell-ninja/hyprconf-v2.git "$tmp_dir/hyprconf-v2"

	# Run the installer
	echo -e "${C_BLUE}[*]${C_RESET} Running installer script..."
	cd "$tmp_dir/hyprconf-v2" || exit 1
	chmod +x hyprconf-v2.sh
	./hyprconf-v2.sh

	# Clean up
	cd - > /dev/null || true
	rm -rf "$tmp_dir"

	echo -e "${C_GREEN}[+]${C_RESET} Hyprland rice configuration installed!"
	echo -e "${C_CYAN}[i]${C_RESET} Log out and select Hyprland as your session from your login manager"
	echo -e "${C_CYAN}[i]${C_RESET} Once logged in, press SUPER + Shift + H to see all keybinds"
	echo -e "${C_CYAN}[i]${C_RESET} Update anytime with SUPER + Shift + U"
	echo -e "${C_CYAN}[i]${C_RESET} Wallpapers go in ~/.config/hypr/Wallpapers/__theme_name/"
}

