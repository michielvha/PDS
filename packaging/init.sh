#!/bin/bash
# PDS (Personal Development Scripts) - Main initialization script
# This script safely loads all PDS function libraries
set -euo pipefail

# Set default library directory (this will contain your bash/debian structure)
PDS_LIB_DIR="${PDS_LIB_DIR:-/usr/share/pds-funcs}"
# Read version from file if available, fallback to default
if [ -r "${PDS_LIB_DIR}/VERSION" ]; then
    PDS_VERSION="$(cat "${PDS_LIB_DIR}/VERSION")"
else
    PDS_VERSION="dev"
fi

# Function to safely source a file
pds_source_file() {
    local file="$1"
    if [ -r "$file" ]; then
        # shellcheck disable=SC1090
        source "$file"
        return 0
    else
        echo "Warning: PDS library file not readable: $file" >&2
        return 1
    fi
}

# Function to show PDS info
pds_info() {
    echo "PDS (Personal Development Scripts) v${PDS_VERSION}"
    echo "Library directory: ${PDS_LIB_DIR}"
    echo "Available function categories:"
    
    if [ -d "${PDS_LIB_DIR}/software" ]; then
        echo "  - software: $(find "${PDS_LIB_DIR}/software" -name "*.sh" -type f | wc -l) functions"
    fi
    if [ -d "${PDS_LIB_DIR}/ui" ]; then
        echo "  - ui: $(find "${PDS_LIB_DIR}/ui" -name "*.sh" -type f | wc -l) functions"
    fi
    if [ -d "${PDS_LIB_DIR}/deploy" ]; then
        echo "  - deploy: $(find "${PDS_LIB_DIR}/deploy" -name "*.sh" -type f | wc -l) functions"
    fi
}

# Load all library files from the debian structure
if [ -d "$PDS_LIB_DIR" ]; then
    # Source software installation functions
    if [ -d "$PDS_LIB_DIR/software" ]; then
        for lib_file in "$PDS_LIB_DIR/software"/*.sh; do
            if [ -f "$lib_file" ]; then
                pds_source_file "$lib_file"
            fi
        done
    fi
    
    # Source UI/theme functions
    if [ -d "$PDS_LIB_DIR/ui" ]; then
        for lib_file in "$PDS_LIB_DIR/ui"/*.sh; do
            if [ -f "$lib_file" ]; then
                pds_source_file "$lib_file"
            fi
        done
    fi
    
    # Source deployment functions
    if [ -d "$PDS_LIB_DIR/deploy" ]; then
        for lib_file in "$PDS_LIB_DIR/deploy"/*.sh; do
            if [ -f "$lib_file" ]; then
                pds_source_file "$lib_file"
            fi
        done
    fi
else
    echo "Warning: PDS library directory not found: $PDS_LIB_DIR" >&2
fi

# Clean up variables
unset lib_file PDS_LIB_DIR

# Export helper function
export -f pds_info 2>/dev/null || true
