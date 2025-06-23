#!/bin/bash
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/debian/ui/install_tokyonight_theme.sh) `

# Function: install_tokyonight_gtk_theme
# Description: Installs and applies the Tokyonight GTK theme
install_tokyonight_gtk_theme() {
	echo "🎨 Installing Tokyonight GTK Theme..."

	# Install necessary packages
	echo "📦 Installing required packages..."
	sudo apt update
	sudo apt install -y sassc gtk2-engines-murrine gnome-themes-extra unzip git

	# Clone the Tokyonight GTK theme repo
	tmp_dir=$(mktemp -d)
	echo "⬇️  Cloning theme repo..."
	git clone --depth=1 https://github.com/Fausto-Korpsvart/Tokyonight-GTK-Theme.git "$tmp_dir"

	# Run the official install script with desired options
	echo "⚙️  Running install script..."
	cd "$tmp_dir/themes" || exit 1
	chmod +x ./install.sh
	./install.sh --color dark --tweaks storm --libadwaita

	# Apply the theme via gsettings
	echo "🎛️  Applying theme settings..."
	gsettings set org.gnome.desktop.interface gtk-theme "Tokyonight-Dark-B"
	gsettings set org.gnome.desktop.wm.preferences theme "Tokyonight-Dark-B"

	echo "✅ Tokyonight GTK Theme installed and applied!"
	echo "💡 Restart apps or logout/login to see the full effect."

	# Clean up
	rm -rf "$tmp_dir"
}
