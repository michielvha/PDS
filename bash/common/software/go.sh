#!/bin/bash
# shellcheck disable=SC2016
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/common/software/go.sh) `

# Function: install_go
# Description: Installs the latest version of Golang and configures the environment for the current user.
#              Supports multiple architectures: x86_64 (amd64), aarch64/arm64, armv6l, armv7l, i386/i686.
# TODO: allow to manually specify which version ?
install_go() {
	echo "🚀 Fetching the latest Go version..."

	# Get the latest Go version dynamically from the official site + Extract just the version number (e.g., go1.21.5 -> 1.21.5)
	# Quote the URL to handle special characters properly (zsh interprets ? as glob pattern)
	GO_VERSION=$(curl -s 'https://go.dev/VERSION?m=text' | head -n 1 | awk '{print $1}' | sed 's/^go//')
	
	if [[ -z "$GO_VERSION" ]]; then
		echo "❌ Failed to retrieve the latest Go version."
		return 1
	fi

	echo "📋 Latest Go version: ${GO_VERSION}"

	# Detect OS and architecture
	OS=$(uname -s | tr '[:upper:]' '[:lower:]')
	ARCH=$(uname -m)

	# Map architecture names to Go's naming convention
	case "$ARCH" in
		x86_64)
			GO_ARCH="amd64"
			;;
		aarch64|arm64)
			GO_ARCH="arm64"
			;;
		armv6l)
			GO_ARCH="armv6l"
			;;
		armv7l)
			GO_ARCH="armv6l"  # Go uses armv6l for both armv6 and armv7
			;;
		i386|i686)
			GO_ARCH="386"
			;;
		*)
			echo "❌ Unsupported architecture: $ARCH"
			return 1
			;;
	esac

	echo "🔍 Detected system: $OS-$GO_ARCH"

	# Define download URL and filename
	GO_TARBALL="go${GO_VERSION}.${OS}-${GO_ARCH}.tar.gz"
	DOWNLOAD_URL="https://go.dev/dl/${GO_TARBALL}"

	echo "📥 Downloading Go ${GO_VERSION} from ${DOWNLOAD_URL}..."
	if ! curl -LO "${DOWNLOAD_URL}"; then
		echo "❌ Failed to download Go ${GO_VERSION}."
		return 1
	fi

	# Validate download
	if [[ ! -f "${GO_TARBALL}" ]]; then
		echo "❌ Download file not found: ${GO_TARBALL}"
		return 1
	fi

	echo "📦 Extracting Go ${GO_VERSION}..."
	sudo rm -rf /usr/local/go
	if ! sudo tar -C /usr/local -xzf "${GO_TARBALL}"; then
		echo "❌ Failed to extract Go ${GO_VERSION}."
		rm -f "${GO_TARBALL}"
		return 1
	fi
	rm "${GO_TARBALL}" # Remove tarball after installation

	echo "✅ Go ${GO_VERSION} installed successfully!"

	# Set up GOPATH and GOBIN
	echo "🔧 Configuring Go environment variables..."

	# Detect user's shell and use appropriate config file
	local detected_shell="bash"  # default
	case "${SHELL:-}" in
		*zsh*)
			detected_shell="zsh"
			;;
		*bash*)
			detected_shell="bash"
			;;
		*)
			# Fallback: check config files
			if [ -f "$HOME/.zshrc" ] && [ ! -f "$HOME/.bashrc" ]; then
				detected_shell="zsh"
			fi
			;;
	esac
	
	case "$detected_shell" in
		zsh)
			SHELL_RC="$HOME/.zshrc"
			;;
		bash|*)
			SHELL_RC="$HOME/.bashrc"
			;;
	esac

	# Check if Go environment is already configured
	if ! grep -q "GOPATH=\$HOME/go" "$SHELL_RC" 2>/dev/null; then
		{
			echo ''
			echo '# Go environment setup'
			echo 'export GOPATH=$HOME/go'
			echo 'export GOBIN=$GOPATH/bin'
			echo 'export PATH=$GOBIN:/usr/local/go/bin:$PATH'
		} >>"$SHELL_RC"
		echo "✅ Go environment added to $SHELL_RC"
	else
		echo "ℹ️  Go environment already configured in $SHELL_RC"
	fi

	# Apply environment variables to current shell (don't source config file as it may cause issues)
	export GOPATH=$HOME/go
	export GOBIN=$GOPATH/bin
	export PATH=$GOBIN:/usr/local/go/bin:$PATH
	
	mkdir -p "$GOBIN" 2>/dev/null || true

	echo "🚀 Go installed! Run 'go version' to check."
}
# Function: set_go_env
# Description: Configures the Go environment variables for the current user.
set_go_env() {
	echo "🔧 Setting Go environment variables for user: $USER"

	# Detect user's shell and use appropriate config file
	local detected_shell="bash"  # default
	case "${SHELL:-}" in
		*zsh*)
			detected_shell="zsh"
			;;
		*bash*)
			detected_shell="bash"
			;;
		*)
			# Fallback: check config files
			if [ -f "$HOME/.zshrc" ] && [ ! -f "$HOME/.bashrc" ]; then
				detected_shell="zsh"
			fi
			;;
	esac
	
	case "$detected_shell" in
		zsh)
			SHELL_RC="$HOME/.zshrc"
			;;
		bash|*)
			SHELL_RC="$HOME/.bashrc"
			;;
	esac

	# Check if Go environment is already configured
	if ! grep -q "GOPATH=\$HOME/go" "$SHELL_RC" 2>/dev/null; then
		{
			echo ''
			echo '# Go environment setup'
			echo 'export GOPATH=$HOME/go'
			echo 'export GOBIN=$GOPATH/bin'
			echo 'export PATH=$GOBIN:/usr/local/go/bin:$PATH'
		} >>"$SHELL_RC"
		echo "✅ Go environment added to $SHELL_RC"
	else
		echo "ℹ️  Go environment already configured in $SHELL_RC"
	fi

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