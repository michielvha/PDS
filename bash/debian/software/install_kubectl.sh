#!/bin/bash
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/debian/software/install_kubectl.sh)`

# Function: install_kubectl
# Description: Installs and configures kubectl
# Reference: https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/#install-using-native-package-management
install_kubectl() {
	# Currently only supports ubuntu using either zsh & bash
	local VERSION="${1:-1.32}"
	
	sudo apt update -y
	sudo apt install -y apt-transport-https ca-certificates curl gnupg
	sudo mkdir -p -m 755 /etc/apt/keyrings
	curl -fsSL "https://pkgs.k8s.io/core:/stable:/v$VERSION/deb/Release.key" | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
	sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg # allow unprivileged APT programs to read this keyring
	echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v$VERSION/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
	sudo chmod 644 /etc/apt/sources.list.d/kubernetes.list # helps tools such as command-not-found to work correctly
	sudo apt update
	sudo apt install -y kubectl

	# Detect shell and set file to update
	local SHELL_NAME
	if [[ -n "$ZSH_VERSION" ]]; then
		SHELL_NAME="zsh"
		PROFILE_FILE="$HOME/.zshrc"
	elif [[ -n "$BASH_VERSION" ]]; then
		SHELL_NAME="bash"
		PROFILE_FILE="$HOME/.bashrc"
	else
		# Fallback to checking $SHELL
		SHELL_NAME=$(basename "$SHELL" 2>/dev/null || echo "bash")
		[[ "$SHELL_NAME" == "zsh" ]] && PROFILE_FILE="$HOME/.zshrc" || PROFILE_FILE="$HOME/.bashrc"
	fi

	# Ensure profile file exists
	[[ -f "$PROFILE_FILE" ]] || touch "$PROFILE_FILE"

	# Ensure autocompletion is set
	if ! grep -qxF "source <(kubectl completion $SHELL_NAME)" "$PROFILE_FILE" 2>/dev/null; then
		echo "source <(kubectl completion $SHELL_NAME)" >> "$PROFILE_FILE"
	fi

	# Ensure alias 'k=kubectl' is set
	if ! grep -qxF "alias k=kubectl" "$PROFILE_FILE" 2>/dev/null; then
		echo "alias k=kubectl" >> "$PROFILE_FILE"
	fi

	# Ensure completion for alias 'k'
	if [[ "$SHELL_NAME" == "zsh" ]]; then
		if ! grep -qxF "compdef __start_kubectl k" "$PROFILE_FILE" 2>/dev/null; then
			echo "compdef __start_kubectl k" >> "$PROFILE_FILE"
		fi
	else
		if ! grep -qxF "complete -F __start_kubectl k" "$PROFILE_FILE" 2>/dev/null; then
			echo "complete -F __start_kubectl k" >> "$PROFILE_FILE"
		fi
	fi

	# Install krew (kubectl plugin manager)
	if ! command -v kubectl-krew &> /dev/null && [[ ! -f "$HOME/.krew/bin/kubectl-krew" ]]; then
		echo "Installing krew (kubectl plugin manager)..."
		local tmp_dir
		tmp_dir=$(mktemp -d)
		cd "$tmp_dir" || return 1
		
		local OS ARCH KREW
		OS="$(uname | tr '[:upper:]' '[:lower:]')"
		ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')"
		KREW="krew-${OS}_${ARCH}"
		
		if curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" && \
		   tar zxvf "${KREW}.tar.gz" && \
		   ./"${KREW}" install krew; then
			echo "krew installed successfully"
		else
			echo "Warning: Failed to install krew"
		fi
		
		cd - > /dev/null || true
		rm -rf "$tmp_dir"
	fi

	# Ensure binary is added to $PATH
	if ! grep -qxF 'export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"' "$PROFILE_FILE" 2>/dev/null; then
		echo 'export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"' >> "$PROFILE_FILE"
	fi

	# Add krew to current session PATH if not already there
	export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"

	# Install kubectl plugins (only if krew is available)
	if command -v kubectl-krew &> /dev/null || [[ -f "$HOME/.krew/bin/kubectl-krew" ]]; then
		echo "Installing kubectl plugins..."
		kubectl krew update 2>/dev/null || true
		
		# Install plugins
		local plugins=("neat" "view-secret" "stern")
		for plugin in "${plugins[@]}"; do
			if kubectl krew install "$plugin" 2>/dev/null; then
				echo "Installed $plugin plugin"
			else
				echo "Warning: Failed to install $plugin plugin"
			fi
		done
	fi

	echo "Installation complete. Restart your terminal or run 'source $PROFILE_FILE' to apply changes."	

	# Install kustomize
	curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh"  | bash
}
