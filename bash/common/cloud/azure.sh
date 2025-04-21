#!/bin/bash
# Common cloud-related functions for Azure
# This module contains functions for managing Azure resources
# ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/common/cloud/azure.sh) `

# Function: install_azcli
# Description: Installs and configures the Azure CLI
# Usage: install_azcli

install_azcli() {
	# quick and easy script maintained by microsoft. Do not use in production.
	curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
}
