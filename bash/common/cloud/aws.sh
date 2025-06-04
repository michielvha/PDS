#!/bin/bash
# Common cloud-related functions for AWS
# This module contains functions for managing AWS resources
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/common/cloud/aws.sh) `

# Function: install_aws_cli
# Description: Installs and configures the AWS CLI
# Usage: install_aws_cli
install_aws_cli() {
	echo "🌩️ Setting up AWS CLI..."

	curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
	unzip awscliv2.zip
	sudo ./aws/install

	# Clean up
	rm -rf awscliv2.zip aws/

	# Verify AWS CLI installation
	aws --version

	echo "✅ AWS CLI installed successfully."
}
