#!/bin/bash
# Configure the selected policy; daemon activation remains an explicit caller step.
restricted_ssh_security_profile() {
    local sshd policy=/etc/ssh/sshd_config.d/00-pds-security.conf
    local work staged effective setting failed=0 previous=0
    if [[ $# -ne 0 ]]; then
        printf '%s\n' 'Usage: restricted_ssh_security_profile' >&2
        return 2
    fi
    sshd="$(command -v sshd || true)"
    [[ -n "$sshd" ]] || sshd=/usr/sbin/sshd
    if [[ ! -x "$sshd" || ! -d /etc/ssh/sshd_config.d ]]; then
        printf '%s\n' 'Install OpenSSH server with sshd_config.d support before configuring its policy.' >&2
        return 1
    fi
    sudo "$sshd" -t || return 1
    work="$(mktemp -d)" || return 1
    cat > "$work/policy" <<'EOF'
# Managed by PDS restricted_ssh_security_profile.
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
PermitRootLogin no
EOF
    if ! sudo "$sshd" -t -f "$work/policy"; then
        rm -rf -- "$work"
        return 1
    fi
    if [[ -e "$policy" ]]; then
        if ! sudo cp -p -- "$policy" "$work/previous"; then
            rm -rf -- "$work"
            return 1
        fi
        previous=1
    fi
    if declare -F pds_before_ssh_policy >/dev/null; then
        if ! pds_before_ssh_policy; then
            rm -rf -- "$work"
            return 1
        fi
    fi
    staged="$(sudo mktemp /etc/ssh/sshd_config.d/.pds-policy.XXXXXX)" || {
        rm -rf -- "$work"
        return 1
    }
    if ! sudo install -m 0644 -o root -g root -- "$work/policy" "$staged" ||
       ! sudo mv -f -- "$staged" "$policy"; then
        sudo rm -f -- "$staged"
        rm -rf -- "$work"
        return 1
    fi
    if ! sudo "$sshd" -t || ! effective="$(sudo "$sshd" -T)"; then
        failed=1
    else
        for setting in 'passwordauthentication no' 'kbdinteractiveauthentication no' \
                       'pubkeyauthentication yes' 'permitrootlogin no'; do
            grep -Fxq -- "$setting" <<< "$effective" || failed=1
        done
    fi
    if [[ "$failed" -ne 0 ]]; then
        if [[ "$previous" -eq 1 ]]; then
            if ! sudo cp -p -- "$work/previous" "$staged" ||
               ! sudo mv -f -- "$staged" "$policy"; then
                printf 'Could not restore SSH policy; previous copy retained in %s\n' "$work" >&2
                return 1
            fi
        elif ! sudo rm -f -- "$policy"; then
            printf 'Could not remove failed SSH policy: %s\n' "$policy" >&2
            return 1
        fi
        rm -rf -- "$work"
        printf '%s\n' 'SSH configuration does not apply the selected PDS policy; restored the previous state.' >&2
        return 1
    fi
    rm -rf -- "$work"
    printf '%s\n' 'SSH policy installed and validated. Reload the SSH service explicitly when ready.'
}
