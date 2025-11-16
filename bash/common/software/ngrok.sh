#!/bin/bash
# shellcheck disable=SC2016
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/common/software/ngrok.sh) `

# Function: install_ngrok
# Description: Installs the latest stable version of ngrok and configures authentication.
#              Supports multiple architectures: x86_64 (amd64), aarch64/arm64.
#              Reference: https://ngrok.com/download
install_ngrok() {
	echo -e "\033[1;34mInstalling ngrok...\033[0m"

	# Detect OS and architecture
	OS=$(uname -s | tr '[:upper:]' '[:lower:]')
	ARCH=$(uname -m)

	# Map architecture names to ngrok's naming convention
	case "$ARCH" in
		x86_64)
			NGROK_ARCH="amd64"
			;;
		aarch64|arm64)
			NGROK_ARCH="arm64"
			;;
		armv6l|armv7l)
			NGROK_ARCH="arm"
			;;
		i386|i686)
			NGROK_ARCH="386"
			;;
		*)
			echo -e "\033[1;31mUnsupported architecture: $ARCH\033[0m"
			exit 1
			;;
	esac

	echo -e "\033[1;36mDetected system: $OS-$NGROK_ARCH\033[0m"

	# Define download URL and filename
	NGROK_TARBALL="ngrok-v3-stable-${OS}-${NGROK_ARCH}.tgz"
	DOWNLOAD_URL="https://bin.equinox.io/c/bNyj1mQVY4c/${NGROK_TARBALL}"

	echo -e "\033[1;33mDownloading ngrok from ${DOWNLOAD_URL}...\033[0m"
	curl -LO "${DOWNLOAD_URL}"

	# Validate download
	if [[ ! -f "$NGROK_TARBALL" ]]; then
		echo -e "\033[1;31mFailed to download ngrok.\033[0m"
		exit 1
	fi

	echo -e "\033[1;33mExtracting ngrok to /usr/local/bin...\033[0m"
	sudo tar -xvzf "${NGROK_TARBALL}" -C /usr/local/bin
	rm "${NGROK_TARBALL}" # Remove tarball after installation

	# Verify installation
	if command -v ngrok &> /dev/null; then
		echo -e "\033[1;32mngrok installed successfully!\033[0m"
		ngrok version
	else
		echo -e "\033[1;31mngrok installation failed.\033[0m"
		exit 1
	fi

	# Configure authentication token
	echo ""
	echo -e "\033[1;33mTo use ngrok, you need to add your authentication token.\033[0m"
	echo "   Get your token from: https://dashboard.ngrok.com/get-started/your-authtoken"
	read -rp "Enter your ngrok auth token (or press Enter to skip): " NGROK_TOKEN

	if [[ -n "$NGROK_TOKEN" ]]; then
		echo -e "\033[1;33mConfiguring ngrok with auth token...\033[0m"
		ngrok config add-authtoken "$NGROK_TOKEN"
		echo -e "\033[1;32mngrok configured successfully!\033[0m"
	else
		echo -e "\033[1;33mSkipped authentication configuration.\033[0m"
		echo "   You can configure it later with: ngrok config add-authtoken <TOKEN>"
	fi

	echo ""
	echo -e "\033[1;32mngrok is ready to use! Try: ngrok http 80\033[0m"
}
