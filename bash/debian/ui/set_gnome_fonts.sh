#!/bin/bash
# Function: set_gnome_fonts
# Description: Configures GNOME fonts and rendering settings
# Source: `source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/debian/ui/set_gnome_fonts.sh)`


set_gnome_fonts() {
	echo "🎨 Setting GNOME fonts and rendering..."

	gsettings set org.gnome.desktop.interface font-name 'JetBrains Mono 11'
	gsettings set org.gnome.desktop.interface document-font-name 'JetBrains Mono 11'
	gsettings set org.gnome.desktop.interface monospace-font-name 'JetBrains Mono 13'

	echo "✅ Font configuration applied."
}
