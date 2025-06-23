#!/bin/bash
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/debian/software/install_librewolf.sh) `

# Function: install_librewolf
# Description: Installs librewolf browser
install_librewolf() {
	sudo apt update && sudo apt install extrepo -y
	sudo extrepo enable librewolf
	sudo apt update && sudo apt install librewolf -y
}
