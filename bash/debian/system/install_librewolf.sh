#!/bin/bash
# Debian-specific system configuration functions
# This module contains functions for configuring the Debian system & installing additional software

# Function: install_librewolf
# Description: Installs librewolf browser
# Usage: install_librewolf
# Arguments: none
# Returns:
#   0 - Success
install_librewolf() {
    sudo apt update && sudo apt install extrepo -y
    sudo extrepo enable librewolf
    sudo apt update && sudo apt install librewolf -y
}
