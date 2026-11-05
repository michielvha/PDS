#!/usr/bin/env bash
# Install the client, provision an account certificate, and prepare user services.
# Run on the target, or use --ssh HOST from an already authenticated machine.
bootstrap_cloudflared_host() (
# PDS auto-sources .sh libraries. Keep options and helpers inside this subshell.
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: bootstrap_cloudflared_host.sh [--ssh USER@HOST] [--cert-file FILE]

The certificate defaults to ~/.cloudflared/cert.pem on this machine.
SSH uses your existing configuration and keys. Remote sudo must work with -n.
No tunnel, DNS record, or public route is created by this command.
EOF
}

die() { printf '%s\n' "$*" >&2; exit 1; }

# Read the certificate only from stdin, never from command arguments or logs.
receive_certificate() (
    set -euo pipefail
    umask 077
    local_dir="$HOME/.cloudflared"
    [[ ! -L "$local_dir" ]] || die "Refusing a symlinked credential directory"
    mkdir -p "$local_dir"
    chmod 700 "$local_dir"
    [[ ! -L "$local_dir/cert.pem" ]] || die "Refusing a symlinked certificate"
    temporary=$(mktemp "$local_dir/.cert.XXXXXX")
    trap 'rm -f "$temporary"' EXIT
    cat > "$temporary"
    [[ -s "$temporary" ]] || die "Certificate is empty"
    grep -q -- '-----BEGIN ARGO TUNNEL TOKEN-----' "$temporary" || die "Not a cloudflared account certificate"
    if [[ -e "$local_dir/cert.pem" ]]; then
        cmp -s "$temporary" "$local_dir/cert.pem" || die "Existing account certificate differs; refusing to replace it"
    else
        # Link atomically without overwriting a concurrently installed certificate.
        ln "$temporary" "$local_dir/cert.pem"
    fi
    chmod 600 "$local_dir/cert.pem"
)

prepare_host() (
    [[ $(uname -s) == Linux ]] || die "This bootstrap requires Linux and systemd"
    command -v systemctl >/dev/null || die "systemd is required"
    if ! command -v cloudflared >/dev/null; then
        # Arch's signed Extra package avoids AUR helpers and unverified binaries.
        # Do not refresh only the package database or upgrade the whole host here.
        if command -v pacman >/dev/null; then
            sudo -n pacman -S --needed --noconfirm cloudflared
        else
            die "Install cloudflared with your distro's installer first, then rerun"
        fi
    fi
    binary=$(command -v cloudflared)
    [[ "$binary" = /* && "$binary" != *[[:space:]\"\\%]* ]] || die "Unsupported cloudflared executable path"
    cloudflared --version
    [[ ! -L "$HOME/.cloudflared" ]] || die "Refusing a symlinked credential directory"
    install -d -m 700 "$HOME/.cloudflared"
    service_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
    mkdir -p "$service_dir"
    unit="$service_dir/pds-cloudflared@.service"
    temporary=$(mktemp)
    trap 'rm -f "$temporary"' EXIT
    cat > "$temporary" <<EOF
[Unit]
Description=PDS Cloudflare Tunnel %i
StartLimitIntervalSec=0

[Service]
Type=simple
ExecStart="$binary" --no-autoupdate tunnel --config "%h/.cloudflared/%i.yml" run
Restart=on-failure
RestartSec=5s
TimeoutStopSec=30s
UMask=0077
NoNewPrivileges=true

[Install]
WantedBy=default.target
EOF
    [[ ! -L "$unit" ]] || die "Refusing a symlinked service template"
    if [[ -e "$unit" ]]; then
        cmp -s "$temporary" "$unit" || die "Existing PDS service template differs; refusing to replace it"
    else
        install -m 644 "$temporary" "$unit"
    fi
    systemctl --user daemon-reload
    sudo -n loginctl enable-linger "$(id -un)"
)

main() {
    local target='' certificate="$HOME/.cloudflared/cert.pem" script receiver
    # Internal phases keep certificate bytes separate from the bootstrap script.
    case "${1:-}" in
        --prepare) [[ $# == 1 ]] || die "Invalid internal arguments"; prepare_host; return ;;
        --receive-certificate) [[ $# == 1 ]] || die "Invalid internal arguments"; receive_certificate; return ;;
    esac
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --ssh) [[ $# -ge 2 ]] || die "--ssh requires a target"; target=$2; shift 2 ;;
            --cert-file) [[ $# -ge 2 ]] || die "--cert-file requires a file"; certificate=$2; shift 2 ;;
            -h|--help) usage; return ;;
            *) usage >&2; die "Unknown argument: $1" ;;
        esac
    done
    [[ -s "$certificate" && -r "$certificate" ]] || die "Readable account certificate required: $certificate"
    grep -q -- '-----BEGIN ARGO TUNNEL TOKEN-----' "$certificate" || die "Not a cloudflared account certificate"
    if [[ -n "$target" ]]; then
        [[ "$target" =~ ^[a-zA-Z0-9_][a-zA-Z0-9_.@-]*$ ]] || die "Use an SSH alias or USER@HOST; configure ports in ~/.ssh/config"
        script=${BASH_SOURCE[0]}
        ssh -o BatchMode=yes -o StrictHostKeyChecking=yes "$target" bash -s -- --prepare < "$script"
        # Only the receiver function and its error helper travel in the command.
        # The credential itself is encrypted by SSH and supplied on stdin.
        receiver="$(declare -f die receive_certificate); receive_certificate"
        receiver=${receiver//\'/\'\\\'\'}
        ssh -o BatchMode=yes -o StrictHostKeyChecking=yes "$target" "bash -c '$receiver'" < "$certificate"
        ssh -o BatchMode=yes -o StrictHostKeyChecking=yes "$target" 'cloudflared tunnel list && loginctl show-user "$(id -un)" -p Linger'
    else
        prepare_host
        receive_certificate < "$certificate"
        cloudflared tunnel list
        loginctl show-user "$(id -un)" -p Linger
    fi
    printf '%s\n' 'Cloudflare host ready. Configure each new tunnel in ~/.cloudflared/NAME.yml.'
}

main "$@"
)

if [[ -n ${BASH_VERSION:-} && ${BASH_SOURCE[0]:-$0} == "$0" ]]; then
    bootstrap_cloudflared_host "$@"
fi
