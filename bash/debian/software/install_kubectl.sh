#!/bin/bash
# Install kubectl with per-user Krew, or explicitly select shared image tooling.

_pds_install_krew() (
    set -euo pipefail
    local pins="$1" arch digest release candidate_digest candidate_release work
    case "$(uname -m)" in
        x86_64) arch=amd64 ;;
        aarch64|arm64) arch=arm64 ;;
        *) printf '%s\n' 'Krew supports amd64 and arm64 in this installer.' >&2; return 1 ;;
    esac
    digest='' release=''
    while read -r candidate_digest candidate_release; do
        if [[ "$candidate_release" == */krew-linux_"$arch".tar.gz ]]; then
            digest=$candidate_digest
            release=$candidate_release
            break
        fi
    done < "$pins"
    if [[ ! "$digest" =~ ^[a-f0-9]{64}$ || ! "$release" =~ ^v[0-9]+\.[0-9]+\.[0-9]+/krew-linux_(amd64|arm64)\.tar\.gz$ ]]; then
        printf '%s\n' 'Missing or invalid packaged Krew checksum.' >&2
        return 1
    fi
    work="$(mktemp -d)" || return 1
    trap 'rm -rf -- "$work"' EXIT
    curl -fsSL "https://github.com/kubernetes-sigs/krew/releases/download/$release" -o "$work/krew.tar.gz" || return 1
    printf '%s  %s\n' "$digest" "$work/krew.tar.gz" | sha256sum --check --status || return 1
    tar -xzf "$work/krew.tar.gz" -C "$work" "./krew-linux_$arch" || return 1
    # Bootstrap from this archive, not the moving krew entry in the plugin index.
    cat > "$work/krew.yaml" <<EOF
apiVersion: krew.googlecontainertools.github.com/v1alpha2
kind: Plugin
metadata:
  name: krew
spec:
  version: "${release%%/*}"
  homepage: https://krew.sigs.k8s.io/
  shortDescription: kubectl plugin manager
  platforms:
  - selector:
      matchLabels:
        os: linux
        arch: $arch
    uri: https://github.com/kubernetes-sigs/krew/releases/download/$release
    sha256: $digest
    files:
    - from: ./krew-linux_$arch
      to: krew
    bin: krew
EOF
    "$work/krew-linux_$arch" install --manifest="$work/krew.yaml" --archive="$work/krew.tar.gz" || return 1
    "$KREW_ROOT/bin/kubectl-krew" update || return 1
    local plugin
    for plugin in neat view-secret stern; do
        "$KREW_ROOT/bin/kubectl-krew" install "$plugin" || return 1
    done
)

install_kubectl() (
    set -euo pipefail
    local channel="${1:-1.37}" mode="${2:-}" assets work profile shell_name hook line
    if [[ $# -gt 2 || ! "$channel" =~ ^1\.[0-9]+$ || ( -n "$mode" && "$mode" != --system ) ]]; then
        printf '%s\n' 'Usage: install_kubectl [minor-channel, e.g. 1.37] [--system]' >&2
        return 2
    fi
    if [[ "$mode" == --system && "$EUID" -ne 0 ]]; then
        printf '%s\n' 'Run --system from a root Bash session; ordinary installation remains per user.' >&2
        return 1
    fi
    work="$(mktemp -d)" || return 1
    trap 'rm -rf -- "$work"' EXIT
    assets="$(dirname -- "${BASH_SOURCE[0]}")/../../config"
    if [[ ! -r "$assets/krew-releases.sha256" ]]; then
        if [[ "$mode" == --system ]]; then
            printf '%s\n' 'Use the installed PDS package or a complete checkout for image assets.' >&2
            return 1
        fi
        # Preserve the standalone raw workstation bootstrap. Fetch data only at
        # the explicit call, from the same ref as its other PDS libraries.
        assets="$work/assets"
        mkdir "$assets" || return 1
        curl -fsSL "https://raw.githubusercontent.com/michielvha/PDS/${PDS_REF:-main}/bash/config/krew-releases.sha256" -o "$assets/krew-releases.sha256" || return 1
    fi
    sudo apt-get update || return 1
    sudo apt-get install -y apt-transport-https ca-certificates curl gnupg git bash-completion || return 1
    curl -fsSL "https://pkgs.k8s.io/core:/stable:/v$channel/deb/Release.key" -o "$work/key.asc" || return 1
    gpg --batch --yes --dearmor -o "$work/key.gpg" "$work/key.asc" || return 1
    sudo install -d -m 0755 /etc/apt/keyrings || return 1
    sudo install -m 0644 "$work/key.gpg" /etc/apt/keyrings/kubernetes-apt-keyring.gpg || return 1
    printf 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v%s/deb/ /\n' "$channel" > "$work/kubernetes.list"
    sudo install -m 0644 "$work/kubernetes.list" /etc/apt/sources.list.d/kubernetes.list || return 1
    sudo apt-get update || return 1
    sudo apt-get install -y kubectl || return 1

    if [[ "$mode" == --system ]]; then
        export KREW_ROOT=/usr/local/share/pds/krew
    else
        export KREW_ROOT="${KREW_ROOT:-$HOME/.krew}"
    fi
    _pds_install_krew "$assets/krew-releases.sha256" || return 1
    if [[ "$mode" == --system ]]; then
        chown -R root:root "$KREW_ROOT" || return 1
        chmod -R go-w "$KREW_ROOT" || return 1
        kubectl completion bash > "$work/completion" || return 1
        printf '\ncomplete -F __start_kubectl k\n' >> "$work/completion"
        install -d -m 0755 /etc/bash_completion.d /etc/profile.d || return 1
        install -m 0644 "$work/completion" /etc/bash_completion.d/pds-kubectl || return 1
        install -m 0644 "$assets/kubectl-profile.sh" /etc/profile.d/pds-kubectl.sh || return 1
        hook='[ ! -r /etc/profile.d/pds-kubectl.sh ] || . /etc/profile.d/pds-kubectl.sh'
        for profile in /etc/bash.bashrc /etc/zsh/zshrc; do
            [[ -f "$profile" ]] || continue
            if ! grep -Fxq "$hook" "$profile"; then
                printf '\n%s\n' "$hook" >> "$profile" || return 1
            fi
        done
    else
        shell_name=bash
        if [[ -n "${ZSH_VERSION:-}" || "${SHELL:-}" == */zsh ]]; then shell_name=zsh; fi
        profile="$HOME/.${shell_name}rc"
        touch "$profile" || return 1
        local lines=(
            'export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"'
            "source <(kubectl completion $shell_name)"
            'alias k=kubectl'
        )
        if [[ "$shell_name" == zsh ]]; then
            lines+=('compdef __start_kubectl k')
        else
            lines+=('complete -F __start_kubectl k')
        fi
        for line in "${lines[@]}"; do
            grep -Fxq "$line" "$profile" || printf '%s\n' "$line" >> "$profile" || return 1
        done
    fi
    printf '%s\n' 'kubectl and required Krew plugins installed. Open a new shell to load the configuration.'
)
