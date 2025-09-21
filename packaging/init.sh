#!/bin/bash
# PDS (Personal Development Scripts) - Main initialization script
# This script safely loads all PDS function libraries
# NOTE: Don't use 'set -e' here as it can crash interactive shells

# Set default library directory (this will contain your bash/debian structure)
PDS_LIB_DIR="${PDS_LIB_DIR:-/usr/share/pds}"

# Function to safely source a file
pds_source_file() {
    local file="$1"
    if [ -r "$file" ]; then
        # shellcheck disable=SC1090
        if source "$file" 2>/dev/null; then
            return 0
        else
            echo "Warning: Failed to load PDS library file: $file" >&2
            return 1
        fi
    else
        echo "Warning: PDS library file not readable: $file" >&2
        return 1
    fi
}

# Load all library files from the dynamic directory structure
if [ -d "$PDS_LIB_DIR" ]; then
    # Dynamically discover platform directories (debian, common, kali, etc.)
    for platform_dir in "$PDS_LIB_DIR"/*; do
        if [ -d "$platform_dir" ] && [ "$(basename "$platform_dir")" != "." ] && [ "$(basename "$platform_dir")" != ".." ]; then
            # Skip if it's just a file
            [ -d "$platform_dir" ] || continue
            
            # Source all .sh files in each category directory within this platform
            for category_dir in "$platform_dir"/*; do
                if [ -d "$category_dir" ]; then
                    # Source all .sh files in this category directory
                    for lib_file in "$category_dir"/*.sh; do
                        # Check if the glob matched any files
                        [ -f "$lib_file" ] || continue
                        pds_source_file "$lib_file"
                    done
                fi
            done
        fi
    done
else
    echo "Warning: PDS library directory not found: $PDS_LIB_DIR" >&2
fi

# Clean up variables
unset lib_file category_dir platform_dir PDS_LIB_DIR
