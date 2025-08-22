#!/bin/bash
# Version management script for PDS package
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Files that contain version information
VERSION_FILES=(
    "$SCRIPT_DIR/nfpm.yaml"
    "$SCRIPT_DIR/Makefile"
    "$SCRIPT_DIR/init.sh"
    "$SCRIPT_DIR/bin/pds"
)

# Function to get current version
get_current_version() {
    grep "^version:" "$SCRIPT_DIR/nfpm.yaml" | awk '{print $2}' | tr -d '"'
}

# Function to update version in all files
update_version() {
    local new_version="$1"
    
    if [[ ! $new_version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Error: Version must follow semantic versioning (e.g., 1.2.3)"
        exit 1
    fi
    
    echo "Updating version to $new_version..."
    
    # Update nfpm.yaml
    sed -i.bak "s/^version: .*/version: $new_version/" "$SCRIPT_DIR/nfpm.yaml"
    
    # Update Makefile
    sed -i.bak "s/^VERSION := .*/VERSION := $new_version/" "$SCRIPT_DIR/Makefile"
    
    # Update init.sh
    sed -i.bak "s/PDS_VERSION=\".*\"/PDS_VERSION=\"$new_version\"/" "$SCRIPT_DIR/init.sh"
    
    # Update CLI helper
    sed -i.bak "s/PDS_VERSION=\".*\"/PDS_VERSION=\"$new_version\"/" "$SCRIPT_DIR/bin/pds"
    
    # Remove backup files
    find "$SCRIPT_DIR" -name "*.bak" -delete
    
    echo "Version updated successfully!"
    echo "Files updated:"
    for file in "${VERSION_FILES[@]}"; do
        echo "  - $(basename "$file")"
    done
}

# Function to bump version
bump_version() {
    local bump_type="$1"
    local current_version
    current_version=$(get_current_version)
    
    IFS='.' read -ra VERSION_PARTS <<< "$current_version"
    local major="${VERSION_PARTS[0]}"
    local minor="${VERSION_PARTS[1]}"
    local patch="${VERSION_PARTS[2]}"
    
    case $bump_type in
        major)
            ((major++))
            minor=0
            patch=0
            ;;
        minor)
            ((minor++))
            patch=0
            ;;
        patch)
            ((patch++))
            ;;
        *)
            echo "Error: Bump type must be 'major', 'minor', or 'patch'"
            exit 1
            ;;
    esac
    
    local new_version="$major.$minor.$patch"
    echo "Bumping $bump_type version: $current_version → $new_version"
    update_version "$new_version"
}

# Function to show version info
show_version_info() {
    local current_version
    current_version=$(get_current_version)
    
    echo "Current PDS Package Version: $current_version"
    echo
    echo "Version information in files:"
    for file in "${VERSION_FILES[@]}"; do
        local filename
        filename=$(basename "$file")
        local version_line
        case $filename in
            nfpm.yaml)
                version_line=$(grep "^version:" "$file" || echo "not found")
                ;;
            Makefile)
                version_line=$(grep "^VERSION :=" "$file" || echo "not found")
                ;;
            init.sh|pds)
                version_line=$(grep "PDS_VERSION=" "$file" | head -1 || echo "not found")
                ;;
        esac
        echo "  $filename: $version_line"
    done
}

# Function to validate version consistency
validate_versions() {
    local current_version
    current_version=$(get_current_version)
    local inconsistent=false
    
    echo "Validating version consistency..."
    
    for file in "${VERSION_FILES[@]}"; do
        local filename
        filename=$(basename "$file")
        local found_version=""
        
        case $filename in
            nfpm.yaml)
                found_version=$(grep "^version:" "$file" | awk '{print $2}' | tr -d '"')
                ;;
            Makefile)
                found_version=$(grep "^VERSION :=" "$file" | awk '{print $3}')
                ;;
            init.sh|pds)
                found_version=$(grep "PDS_VERSION=" "$file" | head -1 | sed 's/.*PDS_VERSION="\([^"]*\)".*/\1/')
                ;;
        esac
        
        if [[ "$found_version" != "$current_version" ]]; then
            echo "❌ Version mismatch in $filename: expected $current_version, found $found_version"
            inconsistent=true
        else
            echo "✅ $filename: $found_version"
        fi
    done
    
    if $inconsistent; then
        echo
        echo "Version inconsistencies found! Run '$0 fix' to synchronize versions."
        exit 1
    else
        echo
        echo "All versions are consistent!"
    fi
}

# Function to show usage
show_usage() {
    echo "PDS Package Version Manager"
    echo
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo
    echo "Commands:"
    echo "  show                    Show current version information"
    echo "  set VERSION             Set specific version (e.g., 1.2.3)"
    echo "  bump TYPE              Bump version (major|minor|patch)"
    echo "  validate                Validate version consistency across files"
    echo "  fix                     Fix version inconsistencies"
    echo
    echo "Examples:"
    echo "  $0 show                 # Show current version"
    echo "  $0 set 1.2.3           # Set version to 1.2.3"
    echo "  $0 bump patch          # Bump patch version"
    echo "  $0 bump minor          # Bump minor version"
    echo "  $0 validate            # Check version consistency"
}

# Main function
main() {
    case "${1:-show}" in
        show)
            show_version_info
            ;;
        set)
            if [[ $# -lt 2 ]]; then
                echo "Error: Version required"
                echo "Usage: $0 set VERSION"
                exit 1
            fi
            update_version "$2"
            ;;
        bump)
            if [[ $# -lt 2 ]]; then
                echo "Error: Bump type required"
                echo "Usage: $0 bump TYPE"
                echo "Types: major, minor, patch"
                exit 1
            fi
            bump_version "$2"
            ;;
        validate)
            validate_versions
            ;;
        fix)
            current_version=$(get_current_version)
            echo "Fixing version inconsistencies using version from nfpm.yaml: $current_version"
            update_version "$current_version"
            ;;
        -h|--help|help)
            show_usage
            ;;
        *)
            echo "Error: Unknown command '$1'"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
