#!/usr/bin/env bash
set -euo pipefail

# Configure the PDS APT repository and install git/zsh in the base OS first.
# Select an exact published package version; there is no implicit latest version.
: "${PDS_VERSION:?Set PDS_VERSION to the exact PDS package version to install}"
sudo apt-get update
sudo apt-get install -y "pds=${PDS_VERSION}"

source /usr/share/pds/init.sh

# Generic image configuration. User identity and SSH keys belong at clone time.
install_zi
configure_zsh
setup_motd "${PDS_MOTD_BANNER:-}" "${PDS_MOTD_INFO:-none}"
