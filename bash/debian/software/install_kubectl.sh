#!/bin/bash
# Function: install_kubectl
# Description: Installs and configures kubectl
# Source: `source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/debian/software/install_kubectl.sh)`

install_kubectl() {
# Currently only supports ubuntu using either zsh & bash
    local VERSION="${1:-1.32}"
    # ✅
    sudo apt update -y
    sudo apt install -y apt-transport-https ca-certificates curl gnupg
    sudo mkdir -p -m 755 /etc/apt/keyrings
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v$VERSION/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg # allow unprivileged APT programs to read this keyring
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v$VERSION/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
    sudo chmod 644 /etc/apt/sources.list.d/kubernetes.list   # helps tools such as command-not-found to work correctly
    sudo apt update
    sudo apt install -y kubectl
    
    # TODO: auto completion configuration ⚠️
    # Detect shell and set file to update
#    SHELL_NAME=$(basename "$SHELL")
#    [[ "$SHELL_NAME" == "zsh" ]] && PROFILE_FILE="$HOME/.zshrc" || PROFILE_FILE="$HOME/.bashrc"
#
#    # Ensure autocompletion is set
#    grep -qxF "source <(kubectl completion $SHELL_NAME)" "$PROFILE_FILE" || echo "source <(kubectl completion $SHELL_NAME)" >> "$PROFILE_FILE"
#
#    # Ensure alias 'k=kubectl' is set
#    grep -qxF "alias k=kubectl" "$PROFILE_FILE" || echo "alias k=kubectl" >> "$PROFILE_FILE"
#
#    # Ensure completion for alias 'k'
#    if [[ "$SHELL_NAME" == "zsh" ]]; then
#        grep -qxF "compdef __start_kubectl k" "$PROFILE_FILE" || echo "compdef __start_kubectl k" >> "$PROFILE_FILE"
#    else
#        grep -qxF "complete -F __start_kubectl k" "$PROFILE_FILE" || echo "complete -F __start_kubectl k" >> "$PROFILE_FILE"
#    fi
#
#    # install krew (kubectl plugin manager) ✅
#    (
#    set -x; cd "$(mktemp -d)" &&
#    OS="$(uname | tr '[:upper:]' '[:lower:]')" &&
#    ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" &&
#    KREW="krew-${OS}_${ARCH}" &&
#    curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" &&
#    tar zxvf "${KREW}.tar.gz" &&
#    ./"${KREW}" install krew
#    )
#    # Ensure binary is added to $PATH
#    grep -qxF 'export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"' "$PROFILE_FILE" || echo 'export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"' >> "$PROFILE_FILE"
#
#    # apply changes
#    source $PROFILE_FILE
#
#    # install kubectl plugins
#    kubectl krew update
#    # view secrets
#    kubectl krew install view-secret
#    # stern
#    kubectl krew install stern
#
#    # source $PROFILE_FILE
#    echo "Installation complete. "  # Restart your terminal or run 'source $PROFILE_FILE' to apply changes.
}
