#!/bin/bash
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/common/utils/detect_distro.sh) `

# Function: detect_distro
# Description: Detects the Linux distribution.
detect_distro() {
    [[ -f /etc/debian_version ]] && echo "debian" || ([[ -f /etc/redhat-release ]] && echo "rhel" || echo "unknown")
}

# Function: get_os_release
# Description: Gets the detailed OS release information
get_os_release() {
    if [[ -f /etc/os-release ]]; then
        # Source the os-release file to get variables
        source /etc/os-release
        echo "${ID:-unknown}"
    elif [[ -f /etc/lsb-release ]]; then
        # Fallback to lsb-release
        source /etc/lsb-release
        echo "${DISTRIB_ID:-unknown}" | tr '[:upper:]' '[:lower:]'
    elif [[ "$(uname)" == "Darwin" ]]; then
        echo "macos"
    elif [[ "$(uname)" == "FreeBSD" ]]; then
        echo "freebsd"
    elif [[ "$(uname)" == "OpenBSD" ]]; then
        echo "openbsd"
    else
        echo "unknown"
    fi
}

# Function: get_package_manager
# Description: Determines the appropriate package manager for the current OS
get_package_manager() {
    local os_release
    os_release=$(get_os_release)
    
    case "$os_release" in
        ubuntu|debian)
            echo "apt"
            ;;
        fedora|centos|rhel)
            command -v dnf >/dev/null 2>&1 && echo "dnf" || echo "yum"
            ;;
        arch|manjaro)
            echo "pacman"
            ;;
        opensuse*|suse*)
            echo "zypper"
            ;;
        alpine)
            echo "apk"
            ;;
        gentoo)
            echo "emerge"
            ;;
        freebsd)
            echo "pkg"
            ;;
        openbsd)
            echo "pkg_add"
            ;;
        macos)
            command -v brew >/dev/null 2>&1 && echo "brew" || echo "none"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}