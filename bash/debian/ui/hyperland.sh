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

	# Verify installation and create desktop entry if needed
	local hyprland_bin=""
	if command -v Hyprland &> /dev/null; then
		hyprland_bin="Hyprland"
	elif command -v hyprland &> /dev/null; then
		hyprland_bin="hyprland"
	else
		echo -e "${C_RED}[-]${C_RESET} Hyprland installation failed - binary not found in PATH"
		return 1
	fi

	# Create desktop entry for login manager if it doesn't exist
	echo -e "${C_BLUE}[*]${C_RESET} Creating desktop entry for login manager..."
	sudo mkdir -p /usr/share/wayland-sessions
	
	if [[ ! -f /usr/share/wayland-sessions/hyprland.desktop ]]; then
		sudo tee /usr/share/wayland-sessions/hyprland.desktop > /dev/null <<EOF
[Desktop Entry]
Name=Hyprland
Comment=Hyprland Wayland compositor
Exec=$hyprland_bin
Type=Application
DesktopNames=Hyprland
EOF
		echo -e "${C_GREEN}[+]${C_RESET} Desktop entry created"
	else
		echo -e "${C_CYAN}[i]${C_RESET} Desktop entry already exists"
	fi

	# Enable Wayland in GDM if using GDM
	if command -v gdm3 &> /dev/null || systemctl is-active --quiet gdm3 2>/dev/null; then
		echo -e "${C_BLUE}[*]${C_RESET} Ensuring Wayland is enabled in GDM..."
		if [[ -f /etc/gdm3/custom.conf ]]; then
			# Check if WaylandEnable is set to false and comment it out
			if grep -q "^WaylandEnable=false" /etc/gdm3/custom.conf; then
				sudo sed -i 's/^WaylandEnable=false/#WaylandEnable=false/' /etc/gdm3/custom.conf
				echo -e "${C_GREEN}[+]${C_RESET} Enabled Wayland in GDM configuration"
			fi
		fi
	fi

	echo -e "${C_GREEN}[+]${C_RESET} Hyprland installed successfully!"
	echo -e "${C_CYAN}[i]${C_RESET} Log out and select 'Hyprland' from the session menu (gear icon) in your login manager"
	echo -e "${C_CYAN}[i]${C_RESET} If Hyprland doesn't appear, you may need to restart your display manager: sudo systemctl restart gdm3"
	return 0
}

# Function: rice
# Description: Installs the Hyprland rice configuration from shell-ninja/hyprconf-v2
rice() {
	echo -e "${C_BLUE}[*]${C_RESET} Installing Hyprland rice configuration..."

	# Check if Hyprland is installed
	if ! command -v Hyprland &> /dev/null && ! command -v hyprland &> /dev/null; then
		echo -e "${C_YELLOW}[!]${C_RESET} Hyprland is not installed. Please run install_hyprland first."
		return 1
	fi

	# Install required dependencies for the installer script
	echo -e "${C_BLUE}[*]${C_RESET} Installing required dependencies..."
	sudo apt update
	if ! sudo apt install -y crudini 2>/dev/null; then
		echo -e "${C_YELLOW}[!]${C_RESET} crudini not available in repositories"
		echo -e "${C_CYAN}[i]${C_RESET} Theme selection may not work properly without crudini"
		echo -e "${C_CYAN}[i]${C_RESET} You can install it manually later if needed"
	else
		echo -e "${C_GREEN}[+]${C_RESET} crudini installed"
	fi

	# Clone the repository
	tmp_dir=$(mktemp -d)
	echo -e "${C_BLUE}[*]${C_RESET} Cloning hyprconf-v2 repository..."
	git clone --depth=1 https://github.com/shell-ninja/hyprconf-v2.git "$tmp_dir/hyprconf-v2"

	# Run the installer
	echo -e "${C_BLUE}[*]${C_RESET} Running installer script..."
	echo -e "${C_YELLOW}[!]${C_RESET} Note: The installer defaults to 'Catppuccin' theme (no prompt)"
	echo -e "${C_CYAN}[i]${C_RESET} After installation, use 'select_hypr_theme' to change themes"
	cd "$tmp_dir/hyprconf-v2" || exit 1
	chmod +x hyprconf-v2.sh
	# Fix the script error on line 188 before running
	sed -i 's/^_____/#_____/' hyprconf-v2.sh 2>/dev/null || true
	./hyprconf-v2.sh

	# Clean up
	cd - > /dev/null || true
	rm -rf "$tmp_dir"

	# Check what was installed
	local wallpapers_dir="$HOME/.config/hypr/Wallpapers"
	if [[ -d "$wallpapers_dir" ]]; then
		echo ""
		echo -e "${C_GREEN}[+]${C_RESET} Hyprland rice configuration installed!"
		echo -e "${C_BLUE}[*]${C_RESET} Installed themes:"
		for theme_dir in "$wallpapers_dir"/*; do
			if [[ -d "$theme_dir" ]]; then
				local theme=$(basename "$theme_dir")
				theme="${theme#__}"
				echo -e "  ${C_CYAN}-${C_RESET} $theme"
			fi
		done
	else
		echo -e "${C_YELLOW}[!]${C_RESET} Installation completed but no themes found."
		echo -e "${C_CYAN}[i]${C_RESET} You may need to run 'select_hypr_theme' to choose a theme"
	fi

	echo ""
	echo -e "${C_CYAN}[i]${C_RESET} Log out and select Hyprland as your session from your login manager"
	echo -e "${C_CYAN}[i]${C_RESET} Once logged in, press SUPER + Shift + H to see all keybinds"
	echo -e "${C_CYAN}[i]${C_RESET} Update anytime with SUPER + Shift + U"
	echo -e "${C_CYAN}[i]${C_RESET} Use 'select_hypr_theme' to change themes if needed"
}

# Function: select_hypr_theme
# Description: Manually switch hyprconf-v2 theme (the installer doesn't prompt for theme selection)
# Usage: select_hypr_theme [theme_name]
select_hypr_theme() {
	local hypr_dir="$HOME/.config/hypr"
	local themes_dir="$hypr_dir/confs/themes"
	local theme_name="$1"

	# Check if hyprconf-v2 is installed
	if [[ ! -d "$themes_dir" ]]; then
		echo -e "${C_RED}[-]${C_RESET} Hyprland rice not installed. Run 'rice' first."
		return 1
	fi

	# List available themes if none specified
	if [[ -z "$theme_name" ]]; then
		echo -e "${C_BLUE}[*]${C_RESET} Available themes:"
		local themes=()
		for theme_file in "$themes_dir"/*.conf; do
			if [[ -f "$theme_file" ]]; then
				local theme=$(basename "$theme_file" .conf)
				themes+=("$theme")
				echo -e "  ${C_CYAN}-${C_RESET} $theme"
			fi
		done

		if [[ ${#themes[@]} -eq 0 ]]; then
			echo -e "${C_YELLOW}[!]${C_RESET} No themes found in $themes_dir"
			return 1
		fi

		echo ""
		echo -e "${C_CYAN}[i]${C_RESET} Usage: select_hypr_theme <theme_name>"
		echo -e "${C_CYAN}[i]${C_RESET} Example: select_hypr_theme Catppuccin"
		return 0
	fi

	# Check if theme exists
	local theme_file="$themes_dir/${theme_name}.conf"
	if [[ ! -f "$theme_file" ]]; then
		echo -e "${C_RED}[-]${C_RESET} Theme '$theme_name' not found"
		echo -e "${C_CYAN}[i]${C_RESET} Run 'select_hypr_theme' without arguments to see available themes"
		return 1
	fi

	echo -e "${C_BLUE}[*]${C_RESET} Switching to theme: $theme_name"

	# Update theme file
	local theme_cache="$hypr_dir/.cache/.theme"
	mkdir -p "$(dirname "$theme_cache")"
	echo "$theme_name" > "$theme_cache"

	# Update symlinks (following the installer script pattern)
	ln -sf "$theme_file" "$hypr_dir/confs/decoration.conf"

	# Rofi theme
	local rofi_theme="$HOME/.config/rofi/colors/${theme_name}.rasi"
	if [[ -f "$rofi_theme" ]]; then
		ln -sf "$rofi_theme" "$HOME/.config/rofi/themes/rofi-colors.rasi"
	fi

	# Kitty theme
	local kitty_theme="$HOME/.config/kitty/colors/${theme_name}.conf"
	if [[ -f "$kitty_theme" ]]; then
		ln -sf "$kitty_theme" "$HOME/.config/kitty/theme.conf"
		# Reload kitty if running
		if command -v kitty &> /dev/null; then
			kill -SIGUSR1 $(pidof kitty) 2>/dev/null || true
		fi
	fi

	# Waybar theme
	local waybar_theme="$HOME/.config/waybar/colors/${theme_name}.css"
	if [[ -f "$waybar_theme" ]]; then
		ln -sf "$waybar_theme" "$HOME/.config/waybar/style/theme.css"
	fi

	# Wlogout theme
	local wlogout_theme="$HOME/.config/wlogout/colors/${theme_name}.css"
	if [[ -f "$wlogout_theme" ]]; then
		ln -sf "$wlogout_theme" "$HOME/.config/wlogout/colors.css"
	fi

	# Swaync theme
	local swaync_theme="$HOME/.config/swaync/colors/${theme_name}.css"
	if [[ -f "$swaync_theme" ]]; then
		ln -sf "$swaync_theme" "$HOME/.config/swaync/colors.css"
	fi

	# Kvantum theme (if crudini available)
	if command -v crudini &> /dev/null; then
		crudini --set "$HOME/.config/Kvantum/kvantum.kvconfig" General theme "$theme_name" 2>/dev/null || true
	fi

	# Run refresh scripts if they exist
	[[ -f "$hypr_dir/scripts/wallcache.sh" ]] && "$hypr_dir/scripts/wallcache.sh" &> /dev/null
	[[ -f "$hypr_dir/scripts/Refresh.sh" ]] && "$hypr_dir/scripts/Refresh.sh" &> /dev/null
	[[ -f "$hypr_dir/scripts/Wallpaper.sh" ]] && "$hypr_dir/scripts/Wallpaper.sh" &> /dev/null

	echo -e "${C_GREEN}[+]${C_RESET} Theme switched to $theme_name"
	echo -e "${C_CYAN}[i]${C_RESET} Restart Hyprland or reload config to see changes"
}

# Function: list_hypr_themes
# Description: Lists installed themes in hyprconf-v2
list_hypr_themes() {
	local wallpapers_dir="$HOME/.config/hypr/Wallpapers"

	if [[ ! -d "$wallpapers_dir" ]]; then
		echo -e "${C_RED}[-]${C_RESET} Hyprland rice not installed. Run 'rice' first."
		return 1
	fi

	echo -e "${C_BLUE}[*]${C_RESET} Installed themes:"
	local count=0
	for theme_dir in "$wallpapers_dir"/*; do
		if [[ -d "$theme_dir" ]]; then
			local theme=$(basename "$theme_dir")
			theme="${theme#__}"  # Remove __ prefix
			local wallpaper_count=$(find "$theme_dir" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.webp" \) 2>/dev/null | wc -l)
			echo -e "  ${C_CYAN}-${C_RESET} $theme (${wallpaper_count} wallpapers)"
			((count++))
		fi
	done

	if [[ $count -eq 0 ]]; then
		echo -e "${C_YELLOW}[!]${C_RESET} No themes found."
		return 1
	fi

	echo ""
	echo -e "${C_CYAN}[i]${C_RESET} To change theme: select_hypr_theme"
	echo -e "${C_CYAN}[i]${C_RESET} To set wallpaper: set_hypr_wallpaper <wallpaper_path> [theme_name]"
}

# Function: set_hypr_wallpaper
# Description: Sets a custom wallpaper for hyprconf-v2 theme
# Usage: set_hypr_wallpaper <wallpaper_path> [theme_name]
set_hypr_wallpaper() {
	local wallpaper_path="$1"
	local theme_name="$2"
	local wallpapers_dir="$HOME/.config/hypr/Wallpapers"

	if [[ -z "$wallpaper_path" ]]; then
		echo -e "${C_RED}[-]${C_RESET} Usage: set_hypr_wallpaper <wallpaper_path> [theme_name]"
		echo -e "${C_CYAN}[i]${C_RESET} Example: set_hypr_wallpaper ~/Pictures/wallpaper.jpg"
		return 1
	fi

	if [[ ! -f "$wallpaper_path" ]]; then
		echo -e "${C_RED}[-]${C_RESET} File not found: $wallpaper_path"
		return 1
	fi

	if [[ ! -d "$wallpapers_dir" ]]; then
		echo -e "${C_RED}[-]${C_RESET} Run 'rice' first to install hyprconf-v2"
		return 1
	fi

	# If no theme specified, find the first available
	if [[ -z "$theme_name" ]]; then
		for theme_dir in "$wallpapers_dir"/*; do
			if [[ -d "$theme_dir" ]]; then
				theme_name=$(basename "$theme_dir")
				theme_name="${theme_name#__}"
				break
			fi
		done
	fi

	# Find theme directory
	local theme_dir=""
	if [[ -d "$wallpapers_dir/__$theme_name" ]]; then
		theme_dir="$wallpapers_dir/__$theme_name"
	elif [[ -d "$wallpapers_dir/$theme_name" ]]; then
		theme_dir="$wallpapers_dir/$theme_name"
	else
		echo -e "${C_RED}[-]${C_RESET} Theme '$theme_name' not found"
		echo -e "${C_CYAN}[i]${C_RESET} Run 'list_hypr_themes' to see available themes"
		return 1
	fi

	# Copy wallpaper
	local filename=$(basename "$wallpaper_path")
	cp "$wallpaper_path" "$theme_dir/$filename" || {
		echo -e "${C_RED}[-]${C_RESET} Failed to copy wallpaper"
		return 1
	}

	echo -e "${C_GREEN}[+]${C_RESET} Wallpaper set: $theme_dir/$filename"
	echo -e "${C_CYAN}[i]${C_RESET} Use SUPER + W in Hyprland to select it, or restart Hyprland"
}