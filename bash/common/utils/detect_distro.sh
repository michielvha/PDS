#!/bin/bash
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/common/utils/detect_distro.sh) `

# Function: detect_distro
# Description: Detects the Linux distribution.
detect_distro() {
    [[ -f /etc/debian_version ]] && echo "debian" || ([[ -f /etc/redhat-release ]] && echo "rhel" || echo "unknown")
}