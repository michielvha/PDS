#!/bin/bash
# shellcheck disable=SC2296
# Common bash shell settings
# Usage: source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/common/shell/.bashrc)

# - aliases -
# Python
alias venv=set_venv
alias python=python3
alias pip=pip3
# Kubectl
alias k='kubectl'
alias kgp='kubectl get pods'
alias kga='kubectl get all'
alias kgn='kubectl get nodes'
alias kgs='kubectl get services'
alias kge='kubectl get events'
alias kgl='kubectl get logs'
alias knr='kubectl get pods --field-selector=status.phase!=Running' # Get pods not in Running state
# Docker
alias dcrenew='docker compose down && docker compose up -d'

# Install bash-completion if not already installed
# Reference: https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/#enable-shell-autocompletion
type _init_completion &>/dev/null || { sudo apt install bash-completion 2>/dev/null || true; }

# Automatically source kubectl completion if kubectl is available
if command -v kubectl >/dev/null 2>&1; then
    # shellcheck disable=SC1090
    source <(kubectl completion bash) 2>/dev/null || true
fi