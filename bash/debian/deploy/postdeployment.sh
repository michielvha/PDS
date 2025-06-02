#!/bin/bash
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/debian/deploy/postdeployment.sh) `

# Function: ubuntu_postdeployment
# Description: This is a super function that combines all ui and software functions into 1 post deployment script.
ubuntu_postdeployment() {
	echo "🔤 Running ubuntu postdeployment function for customizing the OS according to my preferences"

	source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/debian/ui/install_jetbrains_font.sh)
	source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/debian/ui/set_gnome_fonts.sh)
	source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/debian/ui/setup_gnome_extras.sh)
	source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/debian/software/install_vscode.sh)
	source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/debian/software/install_zen.sh)

	# install_jetbrains_font
	# set_gnome_fonts
	setup_gnome_extras # we need to run this, restart and run it again
	install_vscode
	install_zen
	
	echo "✅ Ubuntu postdeployment customization completed!"
}
