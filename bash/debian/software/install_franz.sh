#!/bin/bash
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/debian/software/install_franz.sh) `

# **Not working**

# Function: install_franz
# Description: Installs and configures the Franz messaging app
install_franz() {
	echo "Downloading Franz..."
	FRANZ_URL="https://github.com/meetfranz/franz/releases/download/v5.11.0/franz_5.11.0_amd64.deb"
	DOWNLOAD_PATH="./franz.deb"
	
	# Download with proper flags to ensure complete download
	if ! curl -L -f -# -o "$DOWNLOAD_PATH" "$FRANZ_URL"; then
		echo "Error: Failed to download Franz. Please check your internet connection and try again."
		return 1
	fi
	
	# Verify the file size (basic integrity check)
	FILE_SIZE=$(stat -c%s "$DOWNLOAD_PATH")
	if [ "$FILE_SIZE" -lt 1000000 ]; then # Expected size should be several MB
		echo "Error: Downloaded file is too small, likely incomplete or corrupted."
		rm -f "$DOWNLOAD_PATH"
		return 1
	fi
	
	echo "Installing Franz..."
	if sudo dpkg -i "$DOWNLOAD_PATH"; then
		echo "Installing dependencies..."
		sudo apt-get install -f -y
		echo "Franz installed successfully!"
	else
		echo "Error: Installation failed. Attempting to install dependencies and retry..."
		sudo apt-get install -f -y
		if sudo dpkg -i "$DOWNLOAD_PATH"; then
			echo "Franz installed successfully on second attempt!"
		else
			echo "Error: Failed to install Franz. Try running 'sudo apt-get install -f' manually."
			rm -f "$DOWNLOAD_PATH"
			return 1
		fi
	fi
	
	# Clean up
	rm -f "$DOWNLOAD_PATH"
	return 0
}
