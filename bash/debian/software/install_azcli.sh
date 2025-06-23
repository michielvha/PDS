#!/bin/bash
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/debian/software/install_azcli.sh) `

# Function: install_azcli
# Description: Installs and configures the Azure CLI
install_azcli() {
	sudo apt-get update -y
	sudo apt-get install apt-transport-https ca-certificates curl gnupg lsb-release -y

	sudo mkdir -p /etc/apt/keyrings
	curl -sLS https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /etc/apt/keyrings/microsoft.gpg >/dev/null
	sudo chmod go+r /etc/apt/keyrings/microsoft.gpg


	echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ $(lsb_release -cs) main" | \
	sudo tee /etc/apt/sources.list.d/azure-cli.list

	sudo apt update -y
	sudo apt install azure-cli -y
}
