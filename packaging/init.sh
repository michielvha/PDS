#!/bin/bash
# PDS (Personal Development Scripts) - Main initialization script
# This script safely loads all PDS function libraries
set -euo pipefail

# Set default library directory (this will contain your bash/debian structure)
PDS_LIB_DIR="${PDS_LIB_DIR:-/usr/share/pds}"
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
    
    # Show debian-specific functions
    if [ -d "${PDS_LIB_DIR}/debian" ]; then
        echo "  Debian-specific:"
        while IFS= read -r -d '' subdir; do
            local category
            category=$(basename "$subdir")
            local count
            count=$(find "$subdir" -maxdepth 1 -name "*.sh" -type f | wc -l)
            if [ "$count" -gt 0 ]; then
                echo "    - $category: $count functions"
            fi
        done < <(find "${PDS_LIB_DIR}/debian" -mindepth 1 -type d -print0)
    fi
    
    # Show common functions
    if [ -d "${PDS_LIB_DIR}/common" ]; then
        echo "  Common (cross-platform):"
        while IFS= read -r -d '' subdir; do
            local category
            category=$(basename "$subdir")
            local count
            count=$(find "$subdir" -maxdepth 1 -name "*.sh" -type f | wc -l)
            if [ "$count" -gt 0 ]; then
                echo "    - $category: $count functions"
            fi
        done < <(find "${PDS_LIB_DIR}/common" -mindepth 1 -type d -print0)
    fi
}

# Load all library files recursively from debian and common directories
if [ -d "$PDS_LIB_DIR" ]; then
    # Define the main directories to load from
    main_dirs=("$PDS_LIB_DIR/debian" "$PDS_LIB_DIR/common")
    
    for main_dir in "${main_dirs[@]}"; do
        if [ -d "$main_dir" ]; then
            # Load all .sh files recursively from this directory
            while IFS= read -r -d '' lib_file; do
                pds_source_file "$lib_file"
            done < <(find "$main_dir" -name "*.sh" -type f -print0)
        fi
    done
    
    # Clean up the temporary variable
    unset main_dirs main_dir
else
    echo "Warning: PDS library directory not found: $PDS_LIB_DIR" >&2
fi

# Clean up variables
unset lib_file PDS_LIB_DIR

# Export helper function
export -f pds_info 2>/dev/null || true
