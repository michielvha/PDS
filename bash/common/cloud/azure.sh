#!/bin/bash
# Zsh uses %x for the defining source file; Bash uses BASH_SOURCE.
# shellcheck disable=SC2296
# Compatibility import. Azure CLI installation is Debian-specific.
# Use the PDS package or source the canonical installer from a complete checkout.
# shellcheck source=../../debian/software/install_azcli.sh
source "$(dirname -- "${BASH_SOURCE[0]:-${(%):-%x}}")/../../debian/software/install_azcli.sh"
