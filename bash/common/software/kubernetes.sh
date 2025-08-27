#!/bin/bash
# shellcheck disable=SC2016
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/common/software/kubernetes.sh) `

# Function: configure_kubectl_plugins
# Description: Configures kubectl with autocompletion, aliases, installs krew plugin manager, and sets up useful kubectl plugins (view-secret, stern).
configure_kubectl_plugins() {
	# TODO: auto completion configuration ⚠️
 	# TODO: add to plugin https://github.com/keisku/kubectl-explore
  	# TODO: Maybe change the way we handle this instead of checking imperatively just generate a config file below a caution block and check if the caution block exists 
	# Detect shell and set file to update
    # TODO: move the completion logic to a file that we source and maintain centrally
	   SHELL_NAME=$(basename "$SHELL")
	   [[ "$SHELL_NAME" == "zsh" ]] && PROFILE_FILE="$HOME/.zshrc" || PROFILE_FILE="$HOME/.bashrc"
	
	   # Ensure autocompletion is set
	   grep -qxF "source <(kubectl completion $SHELL_NAME)" "$PROFILE_FILE" || echo "source <(kubectl completion $SHELL_NAME)" >> "$PROFILE_FILE"
	
	   # Ensure alias 'k=kubectl' is set
	   grep -qxF "alias k=kubectl" "$PROFILE_FILE" || echo "alias k=kubectl" >> "$PROFILE_FILE"
	
	   # Ensure completion for alias 'k'
	   if [[ "$SHELL_NAME" == "zsh" ]]; then
	       grep -qxF "compdef __start_kubectl k" "$PROFILE_FILE" || echo "compdef __start_kubectl k" >> "$PROFILE_FILE"
	   else
	       grep -qxF "complete -F __start_kubectl k" "$PROFILE_FILE" || echo "complete -F __start_kubectl k" >> "$PROFILE_FILE"
	   fi
	
        # TODO: rework below into this function()
	   # install krew (kubectl plugin manager) ✅
	   (
	   set -x; cd "$(mktemp -d)" &&
	   OS="$(uname | tr '[:upper:]' '[:lower:]')" &&
	   ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" &&
	   KREW="krew-${OS}_${ARCH}" &&
	   curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" &&
	   tar zxvf "${KREW}.tar.gz" &&
	   ./"${KREW}" install krew
	   )
	   # Ensure binary is added to $PATH
	   grep -qxF 'export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"' "$PROFILE_FILE" || echo 'export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"' >> "$PROFILE_FILE"
	
	   # apply changes
	   source $PROFILE_FILE
	
	   # install kubectl plugins
	   kubectl krew update
	   # view secrets
	   kubectl krew install view-secret
	   # stern
	   kubectl krew install stern
	
	   # source $PROFILE_FILE
	   echo "Installation complete. "  # Restart your terminal or run 'source $PROFILE_FILE' to apply changes.
}
