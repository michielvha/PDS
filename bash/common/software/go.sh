#!/bin/bash

# Function: install_go
# Description: Installs the latest version of Golang and configures the environment for the current user.
# TODO: allow to manually specify which version ?
install_go() {
	echo "🚀 Fetching the latest Go version..."

	# Get the latest Go version dynamically from the official site + Extract just the version number (e.g., go1.21.5 -> 1.21.5)
	GO_VERSION=$(curl -s https://go.dev/VERSION?m=text | head -n 1 | awk '{print $1}' | sed 's/go//')

	# Validate version extraction
	if [[ -z "$GO_VERSION" ]]; then
		echo "❌ Failed to retrieve the latest Go version."
		exit 1
	fi

	# Define download URL and filename
	GO_TARBALL="go${GO_VERSION}.linux-amd64.tar.gz"
	DOWNLOAD_URL="https://go.dev/dl/${GO_TARBALL}"

	echo "📥 Downloading Go ${GO_VERSION} from ${DOWNLOAD_URL}..."
	curl -LO "${DOWNLOAD_URL}"

	echo "📦 Extracting Go ${GO_VERSION}..."
	sudo rm -rf /usr/local/go
	sudo tar -C /usr/local -xzf "${GO_TARBALL}"
	rm "${GO_TARBALL}" # Remove tarball after installation

	echo "✅ Go ${GO_VERSION} installed successfully!"

	# Set up GOPATH and GOBIN
	echo "🔧 Configuring Go environment variables..."

	echo 'export GOPATH=$HOME/go' >>~/.bashrc
	echo 'export GOBIN=$GOPATH/bin' >>~/.bashrc
	echo 'export PATH=$GOBIN:/usr/local/go/bin:$PATH' >>~/.bashrc
	source ~/.bashrc # Apply changes

	echo "🚀 Go installed! Run 'go version' to check."
}
# Function: set_go_env
# Description: Configures the Go environment variables for the current user.
set_go_env() {
	echo "🔧 Setting Go environment variables for user: $USER"

	{
		echo ''
		echo '# Go environment setup'
		echo 'export GOPATH=$HOME/go'
		echo 'export GOBIN=$GOPATH/bin'
		echo 'export PATH=$GOBIN:/usr/local/go/bin:$PATH'
	} >>~/.bashrc

	# Apply it immediately
	export GOPATH=$HOME/go
	export GOBIN=$GOPATH/bin
	export PATH=$GOBIN:/usr/local/go/bin:$PATH

	mkdir -p "$GOBIN"

	echo "✅ Go environment set up. Run 'go version' to check."
}

# Function: setup_edgectl_dev_env
# Description: Sets up the development environment for edgectl with Go installed for the root user. Using root user because edgectl requires root privileges to run.
setup_edgectl_dev_env() {
	echo "🔧 Setting up edgectl development environment for root user..."
	
	# Install Go if not already installed
	if ! command -v go &> /dev/null; then
		echo "Installing Go for root user..."
	    install_go
	fi
	
	# Set up Go environment for root user
	echo "Configuring Go environment for root user..."
	sudo bash -c 'mkdir -p /root/go/bin'
	
	# Add Go environment variables to root's .bashrc if not already there
	if ! sudo grep -q "GOPATH=/root/go" /root/.bashrc; then
		sudo bash -c 'echo "" >> /root/.bashrc'
		sudo bash -c 'echo "# Go environment setup" >> /root/.bashrc'
		sudo bash -c 'echo "export GOPATH=/root/go" >> /root/.bashrc'
		sudo bash -c 'echo "export GOBIN=\$GOPATH/bin" >> /root/.bashrc'
		sudo bash -c 'echo "export PATH=\$GOBIN:/usr/local/go/bin:\$PATH" >> /root/.bashrc'
	fi
	
	# Clone edgectl repository for root user if it doesn't exist
	if [ ! -d "/root/edgectl" ]; then
		echo "Cloning edgectl repository for root user..."
		sudo git clone https://github.com/michielvha/edgectl.git /root/edgectl
	fi
	
	echo "✅ edgectl development environment set up for root user."
	echo "Note: Root user can now run 'go version' to verify the installation."
}