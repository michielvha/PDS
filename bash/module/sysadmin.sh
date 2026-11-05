#!/bin/bash
# Zsh uses %x for the defining source file; Bash uses BASH_SOURCE.
# shellcheck disable=SC2296
# Compatibility import. Administration functions are maintained under common/.
# Use the PDS package or source this file from a complete checkout.
# shellcheck source=../common/admin/sysadmin.sh
source "$(dirname -- "${BASH_SOURCE[0]:-${(%):-%x}}")/../common/admin/sysadmin.sh"
