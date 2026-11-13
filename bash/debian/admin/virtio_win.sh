#!/bin/bash
# VirtIO driver ISO for Windows guests on a KVM host, by default Proxmox VE local ISO storage.
# Upstream publishes no APT repository (Proxmox and Debian do not package virtio-win), so this
# follows Fedora's "stable" redirect and keeps a single virtio-win.iso current.
# Usage: install_virtio_win_iso [iso-directory]
#        enable_virtio_win_iso_updates [iso-directory]

_pds_virtio_win_root() {
    if [[ "$EUID" -eq 0 ]]; then
        "$@"
    else
        sudo "$@"
    fi
}

# Upstream redirects downgrade to plain HTTP; follow each hop over HTTPS on the same tree only.
_pds_virtio_win_resolve() {
    local url='https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso'
    local location hop
    for hop in 1 2 3 4 5; do
        location="$(curl -fsSI --proto =https --max-time 30 -o /dev/null -w '%{redirect_url}' -- "$url")" || {
            printf 'Could not reach %s\n' "$url" >&2
            return 1
        }
        if [[ -z "$location" ]]; then
            printf '%s\n' "$url"
            return 0
        fi
        location="https://${location#*://}"
        if [[ "$location" != https://fedorapeople.org/groups/virt/virtio-win/* || "$location" == *..* ]]; then
            printf 'Refusing unexpected redirect after hop %s: %s\n' "$hop" "$location" >&2
            return 1
        fi
        url="$location"
    done
    printf '%s\n' 'Too many redirects resolving the stable virtio-win ISO.' >&2
    return 1
}

# Print the ISO 9660 volume label (virtio-win-X.Y.Z) of an image whose primary volume
# descriptor starts at byte offset $2.
_pds_virtio_win_label() {
    local file="$1" base="$2" magic label
    magic="$(dd if="$file" bs=1 skip=$((base + 1)) count=5 2>/dev/null)"
    [[ "$magic" == CD001 ]] || return 1
    label="$(dd if="$file" bs=1 skip=$((base + 40)) count=32 2>/dev/null | tr -d ' \000')"
    [[ "$label" =~ ^virtio-win-[0-9]+(\.[0-9]+)+$ ]] || return 1
    printf '%s\n' "$label"
}

# Download or refresh <iso-directory>/virtio-win.iso; a current copy is left untouched.
install_virtio_win_iso() {
    local dir="${1:-/var/lib/vz/template/iso}" target url work remote current staged
    local -a progress=()
    [[ -t 2 ]] || progress=(--no-progress-meter)
    if [[ $# -gt 1 ]]; then
        printf '%s\n' 'Usage: install_virtio_win_iso [iso-directory]' >&2
        return 2
    fi
    if [[ ! -d "$dir" ]]; then
        printf 'ISO directory does not exist: %s\n' "$dir" >&2
        printf '%s\n' 'Proxmox VE local storage uses /var/lib/vz/template/iso; pass the path of another ISO storage.' >&2
        return 1
    fi
    if ! command -v curl >/dev/null; then
        printf '%s\n' 'Install curl before downloading the virtio-win ISO.' >&2
        return 1
    fi
    target="${dir%/}/virtio-win.iso"
    url="$(_pds_virtio_win_resolve)" || return 1

    # Read the upstream version from the ISO header instead of downloading 800+ MB.
    work="$(mktemp -d)" || return 1
    if ! curl -fsS --proto =https --max-time 60 --max-filesize 65536 -r 32768-34815 \
            -o "$work/header" -- "$url" ||
       ! remote="$(_pds_virtio_win_label "$work/header" 0)"; then
        printf 'Could not read the virtio-win version from %s\n' "$url" >&2
        rm -rf -- "$work"
        return 1
    fi
    rm -rf -- "$work"

    if [[ -f "$target" ]] && current="$(_pds_virtio_win_label "$target" 32768)" && [[ "$current" == "$remote" ]]; then
        printf '%s is current (%s).\n' "$target" "$remote"
        return 0
    fi

    printf 'Downloading %s to %s\n' "$remote" "$target"
    # Stage beside the target so the final rename is atomic; the name is not listed as an ISO.
    staged="$(_pds_virtio_win_root mktemp "${dir%/}/.virtio-win.iso.XXXXXX")" || return 1
    if ! ( trap '_pds_virtio_win_root rm -f -- "$staged"' INT TERM
           _pds_virtio_win_root curl -fS --proto =https --retry 3 "${progress[@]}" -o "$staged" -- "$url" ) ||
       ! _pds_virtio_win_root chmod 0644 -- "$staged" ||
       [[ "$(_pds_virtio_win_label "$staged" 32768)" != "$remote" ]]; then
        printf '%s\n' 'Download failed or is not the expected virtio-win ISO; the existing ISO is unchanged.' >&2
        _pds_virtio_win_root rm -f -- "$staged"
        return 1
    fi
    if ! _pds_virtio_win_root mv -f -- "$staged" "$target"; then
        _pds_virtio_win_root rm -f -- "$staged"
        return 1
    fi
    printf 'Installed %s%s.\n' "$remote" "${current:+ (replaced $current)}"
}

# Refresh the ISO weekly from the packaged library, so APT upgrades also update this logic.
enable_virtio_win_iso_updates() {
    local dir="${1:-/var/lib/vz/template/iso}" library=/usr/share/pds/debian/admin/virtio_win.sh work
    if [[ $# -gt 1 ]]; then
        printf '%s\n' 'Usage: enable_virtio_win_iso_updates [iso-directory]' >&2
        return 2
    fi
    if [[ ! -d "$dir" || ! "$dir" =~ ^/[A-Za-z0-9/._-]+$ ]]; then
        printf 'ISO directory must be an existing absolute path without spaces: %s\n' "$dir" >&2
        return 1
    fi
    if [[ ! -r "$library" ]]; then
        printf '%s\n' 'Install the pds package first; the scheduled refresh loads this function from it.' >&2
        return 1
    fi
    if [[ ! -x /usr/sbin/cron ]]; then
        printf '%s\n' 'Install cron before enabling scheduled virtio-win updates.' >&2
        return 1
    fi
    work="$(mktemp)" || return 1
    cat > "$work" <<EOF
# Managed by PDS enable_virtio_win_iso_updates. Remove this file to stop the refresh.
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
17 4 * * 0 root test -r $library && . $library && install_virtio_win_iso $dir >> /var/log/pds-virtio-win.log 2>&1
EOF
    if ! _pds_virtio_win_root install -d -m 0755 /etc/cron.d ||
       ! _pds_virtio_win_root install -m 0644 -o root -g root -- "$work" /etc/cron.d/pds-virtio-win; then
        rm -f -- "$work"
        return 1
    fi
    rm -f -- "$work"
    printf 'Weekly virtio-win refresh scheduled for Sunday 04:17 into %s (log: /var/log/pds-virtio-win.log).\n' "$dir"
}
