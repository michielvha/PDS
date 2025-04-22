#!/bin/bash
# Function: install_juno_theme
# Description: Installs and applies the Juno GTK theme
# Source: `source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/debian/ui/install_juno_themes.sh)`

install_juno_theme() {
	echo "🎨 Installing Juno GTK Theme..."

	# Variables
	THEME_URL="https://github.com/EliverLara/Juno/archive/refs/heads/master.zip"
	THEME_NAME="Juno"
	THEME_DIR="$HOME/.themes"

	# Create theme directory if it doesn't exist
	mkdir -p "$THEME_DIR"

	# Download and extract
	tmp_dir=$(mktemp -d)
	echo "⬇️  Downloading theme..."
	wget -q --show-progress -O "$tmp_dir/juno.zip" "$THEME_URL"

	echo "📦 Extracting theme to $THEME_DIR..."
	unzip -q "$tmp_dir/juno.zip" -d "$tmp_dir"
	mv "$tmp_dir/Juno-master" "$THEME_DIR/$THEME_NAME"

	# Set the theme via gsettings
	echo "⚙️  Setting Juno as the GTK and WM theme..."
	gsettings set org.gnome.desktop.interface gtk-theme "$THEME_NAME"
	gsettings set org.gnome.desktop.wm.preferences theme "$THEME_NAME"

	# Workaround to Apply Juno Theme to Libadwaita Apps
	mkdir -p ~/.config/gtk-4.0-backup
	cp -r ~/.config/gtk-4.0/* ~/.config/gtk-4.0-backup/ 2>/dev/null || true
	mkdir -p ~/.config/gtk-4.0
	cp -r ~/.themes/Juno/gtk-4.0/* ~/.config/gtk-4.0/

	echo "✅ Juno theme installed and applied!"
	echo "💡 You can also tweak more in GNOME Tweaks if needed."

	# Clean up
	rm -rf "$tmp_dir"
}
