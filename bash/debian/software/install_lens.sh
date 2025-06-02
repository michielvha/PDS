#!/bin/bash
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/debian/software/install_lens.sh) `

# Function: install_lens
# Description: Installs and configures lens (Kubernetes IDE) on a Debian-based system.
# Reference: https://docs.k8slens.dev/getting-started/install-lens/#install-lens-desktop-from-the-apt-repository
install_lens() {
	curl -fsSL https://downloads.k8slens.dev/keys/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/lens-archive-keyring.gpg > /dev/null
	echo "deb [arch=amd64 signed-by=/usr/share/keyrings/lens-archive-keyring.gpg] https://downloads.k8slens.dev/apt/debian stable main" | \
	sudo tee /etc/apt/sources.list.d/lens.list > /dev/null
	sudo apt update && sudo apt install lens
}

# Function: install_freelens
# Description: Installs FreeLens (Open-source alternative to Lens) on a Debian-based system.
install_freelens() {
	echo "🔍 Installing FreeLens from GitHub releases..."
	
	# Create a temporary directory
	tmp_dir=$(mktemp -d)
	cd "$tmp_dir" || return 1
	
	# Define the package URL and filename
	FREELENS_URL="https://github.com/freelensapp/freelens/releases/download/v1.3.1/Freelens-1.3.1-linux-amd64.deb"
	FREELENS_PKG="freelens.deb"
	
	echo "⬇️ Downloading: $FREELENS_URL"
	if ! curl -L -o "$FREELENS_PKG" "$FREELENS_URL"; then
		echo "❌ Failed to download FreeLens package."
		cd /
		rm -rf "$tmp_dir"
		return 1
	fi
	
	echo "📦 Installing FreeLens package..."
	if ! sudo apt install -y ./"$FREELENS_PKG"; then
		echo "❌ Failed to install FreeLens package."
		cd /
		rm -rf "$tmp_dir"
		return 1
	fi
	
	# Cleanup
	cd /
	rm -rf "$tmp_dir"
	echo "✅ FreeLens installed successfully!"
}