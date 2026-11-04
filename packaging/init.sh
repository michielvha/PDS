#!/bin/bash
# Load library definitions without changing the caller's shell options.

pds_source_file() {
    local file="$1"
    if [[ ! -r "$file" ]]; then
        printf 'PDS library file is not readable: %s\n' "$file" >&2
        return 1
    fi
    # shellcheck disable=SC1090
    if source "$file"; then
        return 0
    fi
    printf 'Failed to load PDS library file: %s\n' "$file" >&2
    return 1
}

_pds_load_libraries() {
    local library_dir="${PDS_LIB_DIR:-/usr/share/pds}"
    local platform_dir category_dir lib_file
    if [[ ! -d "$library_dir" ]]; then
        printf 'PDS library directory not found: %s\n' "$library_dir" >&2
        return 1
    fi
    for platform_dir in "$library_dir"/*; do
        [[ -d "$platform_dir" ]] || continue
        for category_dir in "$platform_dir"/*; do
            [[ -d "$category_dir" ]] || continue
            for lib_file in "$category_dir"/*.sh; do
                [[ -f "$lib_file" ]] || continue
                pds_source_file "$lib_file" || return 1
            done
        done
    done
}

_pds_load_libraries
