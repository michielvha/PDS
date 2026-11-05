#!/usr/bin/env bash
# Invoked by the managed cron job, without a login/provisioning environment.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
export LC_ALL=C

lock_timeout="${PDS_UPDATE_LOCK_TIMEOUT:-300}"
if [[ ! "$lock_timeout" =~ ^[1-9][0-9]{0,2}$ || "$lock_timeout" -gt 300 ]]; then
    printf '%s\n' 'PDS_UPDATE_LOCK_TIMEOUT must be between 1 and 300 seconds.' >&2
    exit 2
fi
lock_budget=$lock_timeout
output="$(mktemp)"
trap 'rm -f -- "$output"' EXIT

run_apt() {
    local started elapsed status
    while true; do
        if [[ "$lock_budget" -le 0 ]]; then
            printf '%s\n' 'Timed out waiting for APT/dpkg locks.' >&2
            return 100
        fi
        started=$SECONDS
        if apt-get -o "DPkg::Lock::Timeout=$lock_budget" "$@" > "$output" 2>&1; then
            cat "$output"
            return 0
        else
            status=$?
        fi
        cat "$output" >&2
        if ! grep -Eq 'Could not get lock|Unable to acquire.*lock|Unable to lock directory' "$output"; then
            return "$status"
        fi
        elapsed=$((SECONDS - started))
        lock_budget=$((lock_budget - elapsed))
        if [[ "$lock_budget" -le 0 ]]; then
            printf '%s\n' 'Timed out waiting for APT/dpkg locks.' >&2
            return "$status"
        fi
        sleep 1
        lock_budget=$((lock_budget - 1))
    done
}

run_apt update
run_apt -y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold upgrade
