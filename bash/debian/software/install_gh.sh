#!/bin/bash
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/debian/software/install_gh.sh) `

# Function: install_gh
# Description: Installs the GitHub CLI from GitHub's official apt repository on Debian-based systems.
#              The distro-provided `gh` package is either missing or badly out of date on most releases,
#              and the bootstrap depends on flags like `gh repo list --no-archived`.
install_gh() {
	command -v gh >/dev/null 2>&1 && { echo "ℹ️  gh already installed ($(gh --version | head -n1))"; return 0; }

	echo "🐙 Installing GitHub CLI..."

	sudo apt-get update
	sudo apt-get install -y curl ca-certificates

	sudo install -m 0755 -d /etc/apt/keyrings
	curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
		| sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
	sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg

	echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
		| sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null

	sudo apt-get update
	sudo apt-get install -y gh

	command -v gh >/dev/null 2>&1 \
		&& echo "✅ GitHub CLI installed ($(gh --version | head -n1))" \
		|| { echo "❌ GitHub CLI installation failed"; return 1; }
}
