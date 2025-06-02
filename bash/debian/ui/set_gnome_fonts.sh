#!/bin/bash
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/debian/ui/set_gnome_fonts.sh) `

# Function: set_gnome_fonts
# Description: Configures GNOME fonts and rendering settings
set_gnome_fonts() {
	echo "🎨 Setting GNOME fonts and rendering..."

	# gsettings set org.gnome.desktop.interface font-name 'JetBrains Mono 11'
	# gsettings set org.gnome.desktop.interface document-font-name 'JetBrains Mono 11'
	# gsettings set org.gnome.desktop.interface monospace-font-name 'JetBrains Mono 13'

	gsettings set org.gnome.desktop.interface font-name 'Noto Sans Regular 11'
	gsettings set org.gnome.desktop.interface document-font-name 'Noto Sans Regular 11'
	gsettings set org.gnome.desktop.interface monospace-font-name 'Noto Sans Mono Regular 13'

	echo "✅ Font configuration applied."
}
