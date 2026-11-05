# Installed only by install_kubectl --system; compatible with Bash and Zsh.
export KREW_ROOT="${KREW_ROOT:-/usr/local/share/pds/krew}"
case ":$PATH:" in
    *":$KREW_ROOT/bin:"*) ;;
    *) export PATH="$KREW_ROOT/bin:$PATH" ;;
esac
alias k=kubectl
if [ -n "${BASH_VERSION:-}" ] && [ -r /etc/bash_completion.d/pds-kubectl ]; then
    . /etc/bash_completion.d/pds-kubectl
fi
