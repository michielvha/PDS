#!/bin/bash
# Zsh uses %x for the defining source file; Bash uses BASH_SOURCE.
# shellcheck disable=SC2296
# Debian/Ubuntu dynamic MOTD setup; preserve distribution MOTD scripts.
# Usage: setup_motd [banner-file] [none|fastfetch|neofetch]
setup_motd() {
    local banner_file="${1:-}" information="${2:-none}" script
    if [[ -n "$banner_file" && ( ! -f "$banner_file" || ! -r "$banner_file" ) ]]; then
        printf 'MOTD banner is not a readable file: %s\n' "$banner_file" >&2
        return 1
    fi
    case "$information" in
        none) ;;
        fastfetch|neofetch)
            if ! command -v "$information" >/dev/null 2>&1; then
                printf 'Install %s before selecting it for the MOTD.\n' "$information" >&2
                return 1
            fi
            ;;
        *) printf '%s\n' 'System information command must be none, fastfetch or neofetch.' >&2; return 1 ;;
    esac

    script="$(mktemp)" || return
    cat > "$script" <<'EOF'
#!/bin/sh
if [ -r /etc/pds/motd-banner ]; then
    cat /etc/pds/motd-banner
else
    uname -sr
fi
EOF
    if [[ "$information" != none ]]; then
        printf 'if command -v %s >/dev/null 2>&1; then %s; fi\n' "$information" "$information" >> "$script"
    fi
    if ! sudo install -d /etc/pds /etc/update-motd.d; then
        rm -f -- "$script"
        return 1
    fi
    if [[ -n "$banner_file" ]]; then
        if ! sudo install -m 0644 -- "$banner_file" /etc/pds/motd-banner; then
            rm -f -- "$script"
            return 1
        fi
    else
        sudo rm -f /etc/pds/motd-banner || { rm -f -- "$script"; return 1; }
    fi
    if ! sudo install -m 0755 -- "$script" /etc/update-motd.d/90-pds; then
        rm -f -- "$script"
        return 1
    fi
    rm -f -- "$script"
}

# Select a bundled text banner; adding a preset requires only a new asset file.
setup_motd_preset() {
    local preset="${1:-}" information="${2:-none}" banner_dir
    if [[ $# -lt 1 || $# -gt 2 || ! "$preset" =~ ^[a-z0-9][a-z0-9_-]*$ ]]; then
        printf '%s\n' 'Usage: setup_motd_preset <preset-name> [none|fastfetch|neofetch]' >&2
        return 2
    fi
    banner_dir="$(dirname -- "${BASH_SOURCE[0]:-${ZSH_VERSION:+${(%):-%x}}}")/../../config/motd"
    if [[ ! -r "$banner_dir/$preset.txt" ]]; then
        printf 'Unknown or unreadable MOTD preset: %s\n' "$preset" >&2
        return 1
    fi
    setup_motd "$banner_dir/$preset.txt" "$information"
}
