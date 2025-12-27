#!/bin/bash
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/common/utils/detect_arch.sh) `

# Function: detect_arch
# Description: Detects the system architecture (returns raw uname -m output)
detect_arch() {
	uname -m
}

# Function: detect_os
# Description: Detects the operating system (lowercase, e.g., linux, darwin)
detect_os() {
	uname -s | tr '[:upper:]' '[:lower:]'
}

# Function: map_arch_to_go
# Description: Maps system architecture to Go's naming convention
#              x86_64 -> amd64, aarch64/arm64 -> arm64, armv6l/armv7l -> armv6l, etc.
map_arch_to_go() {
	local arch="${1:-$(detect_arch)}"
	
	case "$arch" in
		x86_64)
			echo "amd64"
			;;
		aarch64|arm64)
			echo "arm64"
			;;
		armv6l)
			echo "armv6l"
			;;
		armv7l)
			echo "armv6l"  # Go uses armv6l for both armv6 and armv7
			;;
		i386|i686)
			echo "386"
			;;
		*)
			echo "❌ Unsupported architecture: $arch" >&2
			return 1
			;;
	esac
}

# Function: map_arch_to_standard
# Description: Maps system architecture to standard naming convention (amd64, arm64, armv6, armv7, etc.)
#              Used by tools like golangci-lint, GitHub releases, etc.
map_arch_to_standard() {
	local arch="${1:-$(detect_arch)}"
	
	case "$arch" in
		x86_64)
			echo "amd64"
			;;
		aarch64|arm64)
			echo "arm64"
			;;
		armv6l)
			echo "armv6"
			;;
		armv7l)
			echo "armv7"
			;;
		i386|i686)
			echo "386"
			;;
		*)
			echo "❌ Unsupported architecture: $arch" >&2
			return 1
			;;
	esac
}

