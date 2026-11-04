#!/bin/bash
# Compatibility import. Azure CLI installation is Debian-specific.
# Use the PDS package or source the canonical installer from a complete checkout.
# shellcheck source=../../debian/software/install_azcli.sh
source "$(dirname -- "${BASH_SOURCE[0]}")/../../debian/software/install_azcli.sh"
