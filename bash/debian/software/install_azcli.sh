#!/bin/bash
# Function: install_azcli
# Description: Installs and configures the Azure CLI
# Source: `source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/debian/system/install_azcli.sh)`

install_azcli() {
	sudo apt-get update -y
	sudo apt-get install apt-transport-https ca-certificates curl gnupg lsb-release -y

	sudo mkdir -p /etc/apt/keyrings
	curl -sLS https://packages.microsoft.com/keys/microsoft.asc |
		gpg --dearmor | sudo tee /etc/apt/keyrings/microsoft.gpg >/dev/null
	sudo chmod go+r /etc/apt/keyrings/microsoft.gpg

	AZ_DIST=$(lsb_release -cs)
	echo "Types: deb
  URIs: https://packages.microsoft.com/repos/azure-cli/
  Suites: ${AZ_DIST}
  Components: main
  Architectures: $(dpkg --print-architecture)
  Signed-by: /etc/apt/keyrings/microsoft.gpg" | sudo tee /etc/apt/sources.list.d/azure-cli.sources

	sudo apt update -y
	sudo apt install azure-cli -y
}
