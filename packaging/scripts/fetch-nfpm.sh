#!/usr/bin/env bash
# Fetch the verified amd64 Linux compiler into a new local tool directory.
set -euo pipefail
[[ $# == 1 ]] || { printf '%s\n' 'Usage: fetch-nfpm.sh <new-tool-directory>' >&2; exit 2; }
[[ "$(uname -s)" == Linux && "$(uname -m)" == x86_64 ]] || { printf '%s\n' 'This bounded package check needs an amd64 Linux host.' >&2; exit 1; }
destination=$1
# renovate: datasource=github-release-attachments depName=goreleaser/nfpm
nfpm_version=v2.48.0
nfpm_sha256=6d7f9a28b2f397934403950fcbba83f598b08d02edbe79a0815b3b4897341750
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
mkdir -- "$destination"
curl -fsSL "https://github.com/goreleaser/nfpm/releases/download/$nfpm_version/nfpm_${nfpm_version#v}_Linux_x86_64.tar.gz" -o "$work/nfpm.tar.gz"
printf '%s  %s\n' "$nfpm_sha256" "$work/nfpm.tar.gz" | sha256sum --check --status
tar -xzf "$work/nfpm.tar.gz" -C "$destination" nfpm
printf 'Verified nFPM %s in %s\n' "$nfpm_version" "$destination"
