#!/bin/bash
# Automated build script for PDS package
set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PACKAGE_NAME="pds-funcs"
VERSION="${VERSION:-1.0.0}"
DIST_DIR="$SCRIPT_DIR/dist"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    local missing_tools=()
    
    if ! command -v nfpm &> /dev/null; then
        missing_tools+=("nfpm")
    fi
    
    if ! command -v make &> /dev/null; then
        missing_tools+=("make")
    fi
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Install with:"
        for tool in "${missing_tools[@]}"; do
            case $tool in
                nfpm)
                    echo "  curl -sfL https://install.goreleaser.com/github.com/goreleaser/nfpm.sh | sh"
                    ;;
                make)
                    echo "  sudo apt-get install build-essential"
                    ;;
            esac
        done
        exit 1
    fi
    
    log_success "All prerequisites satisfied"
}

# Function to validate source structure
validate_source() {
    log_info "Validating source structure..."
    
    local source_dirs=(
        "$PROJECT_ROOT/bash/debian/software"
        "$PROJECT_ROOT/bash/debian/ui"
        "$PROJECT_ROOT/bash/debian/deploy"
    )
    
    for dir in "${source_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            log_error "Source directory not found: $dir"
            exit 1
        fi
        
        local script_count
        script_count=$(find "$dir" -name "*.sh" -type f | wc -l)
        log_info "Found $script_count scripts in $(basename "$dir")"
    done
    
    log_success "Source structure validation passed"
}

# Function to run linting
run_linting() {
    log_info "Running linting checks..."
    
    if command -v shellcheck &> /dev/null; then
        local lint_failed=false
        
        # Lint packaging scripts
        for script in "$SCRIPT_DIR"/*.sh "$SCRIPT_DIR"/bin/* "$SCRIPT_DIR"/scripts/*.sh; do
            if [[ -f "$script" ]]; then
                if ! shellcheck "$script"; then
                    lint_failed=true
                fi
            fi
        done
        
        # Lint source scripts
        while IFS= read -r -d '' script; do
            if ! shellcheck "$script"; then
                lint_failed=true
            fi
        done < <(find "$PROJECT_ROOT/bash/debian" -name "*.sh" -type f -print0)
        
        if $lint_failed; then
            log_warning "Linting found issues, but continuing build..."
        else
            log_success "Linting passed"
        fi
    else
        log_warning "shellcheck not found, skipping linting"
    fi
}

# Function to build package
build_package() {
    log_info "Building $PACKAGE_NAME v$VERSION..."
    
    cd "$SCRIPT_DIR"
    
    # Clean previous builds
    rm -rf "$DIST_DIR"
    mkdir -p "$DIST_DIR"
    
    # Make scripts executable
    chmod +x scripts/*.sh bin/pds
    
    # Build package
    if nfpm pkg --packager deb --config nfpm.yaml --target "$DIST_DIR/"; then
        log_success "Package built successfully"
        
        # Find the actual package file created (most recent with correct naming)
        local package_file
        package_file=$(ls -t "$DIST_DIR/${PACKAGE_NAME}_"*_all.deb 2>/dev/null | head -1)
        
        if [[ -f "$package_file" ]]; then
            local size
            size=$(du -h "$package_file" | cut -f1)
            log_info "Package size: $size"
            log_info "Package location: $package_file"
            
            # Show package contents
            log_info "Package contents:"
            if ! package_contents=$(dpkg-deb -c "$package_file" 2>/dev/null); then
                log_warning "Could not read package contents"
            else
                echo "$package_contents" | head -20
                local total_files
                total_files=$(echo "$package_contents" | wc -l)
                if [[ $total_files -gt 20 ]]; then
                    echo "  ... and $((total_files - 20)) more files"
                fi
            fi
        else
            log_warning "Package file not found for display"
        fi
    else
        log_error "Package build failed"
        exit 1
    fi
}

# Function to validate package
validate_package() {
    log_info "Validating package..."
    
    # Find the actual package file created (nfpm might change version format)
    local package_file
    package_file=$(ls -t "$DIST_DIR/${PACKAGE_NAME}_"*_all.deb 2>/dev/null | head -1)
    
    if [[ ! -f "$package_file" ]]; then
        log_error "Package file not found in: $DIST_DIR"
        log_error "Expected pattern: ${PACKAGE_NAME}_*.deb"
        log_error "Available files:"
        ls -la "$DIST_DIR" || true
        exit 1
    fi
    
    log_info "Found package: $(basename "$package_file")"
    
    # Check package info
    if dpkg-deb -I "$package_file" > /dev/null; then
        log_success "Package structure is valid"
    else
        log_error "Package structure validation failed"
        exit 1
    fi
    
    # Check for required files in package
    local required_files=(
        "./usr/share/pds-funcs/init.sh"
        "./usr/share/pds-funcs/VERSION"
        "./etc/profile.d/pds-funcs.sh"
        "./usr/bin/pds"
    )
    
    log_info "Checking package contents..."
    local package_contents
    if ! package_contents=$(dpkg-deb -c "$package_file" 2>&1); then
        log_error "Failed to read package contents: $package_contents"
        exit 1
    fi
    
    for file in "${required_files[@]}"; do
        if ! echo "$package_contents" | grep -q "$file"; then
            log_error "Required file missing from package: $file"
            log_info "Package contents:"
            echo "$package_contents" | head -20
            exit 1
        fi
    done
    
    log_success "Package validation passed"
}

# Function to test package installation
test_installation() {
    log_info "Testing package installation..."
    
    if command -v docker &> /dev/null; then
        # Find the actual package file (nfpm may change the filename format)
        local package_file
        package_file=$(ls -t "$DIST_DIR/${PACKAGE_NAME}_"*_all.deb 2>/dev/null | head -1)
        
        if [[ ! -f "$package_file" ]]; then
            log_error "No package file found in $DIST_DIR"
            exit 1
        fi
        
        log_info "Testing package: $(basename "$package_file")"
        
        # Test in clean Ubuntu container
        if docker run --rm -v "$DIST_DIR:/packages" ubuntu:22.04 /bin/bash -c "
            apt-get update -qq &&
            apt-get install -y /packages/$(basename "$package_file") &&
            pds doctor &&
            pds list | head -10 &&
            echo 'Installation test passed'
        "; then
            log_success "Installation test passed"
        else
            log_error "Installation test failed"
            exit 1
        fi
    else
        log_warning "Docker not available, skipping installation test"
    fi
}

# Function to show usage
show_usage() {
    echo "PDS Package Builder"
    echo
    echo "Usage: $0 [OPTIONS] [COMMAND]"
    echo
    echo "Commands:"
    echo "  build      Build the package (default)"
    echo "  test       Build and test the package"
    echo "  lint       Run linting only"
    echo "  validate   Validate package structure only"
    echo "  clean      Clean build artifacts"
    echo
    echo "Options:"
    echo "  -v, --version VERSION    Set package version (default: $VERSION)"
    echo "  -h, --help              Show this help"
    echo
    echo "Environment variables:"
    echo "  VERSION                 Package version override"
    echo
    echo "Examples:"
    echo "  $0                      # Build package"
    echo "  $0 test                 # Build and test"
    echo "  $0 --version 1.1.0 build  # Build with specific version"
}

# Main function
main() {
    local command="build"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--version)
                VERSION="$2"
                shift 2
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            build|test|lint|validate|clean)
                command="$1"
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    case $command in
        build)
            check_prerequisites
            validate_source
            run_linting
            build_package
            validate_package
            log_success "Build completed successfully!"
            ;;
        test)
            check_prerequisites
            validate_source
            run_linting
            build_package
            validate_package
            test_installation
            log_success "Build and test completed successfully!"
            ;;
        lint)
            run_linting
            ;;
        validate)
            check_prerequisites
            validate_source
            if [[ -f "$DIST_DIR/${PACKAGE_NAME}_${VERSION}_all.deb" ]]; then
                validate_package
            else
                log_warning "No package found to validate"
            fi
            ;;
        clean)
            log_info "Cleaning build artifacts..."
            rm -rf "$DIST_DIR"
            log_success "Clean completed"
            ;;
    esac
}

# Run main function with all arguments
main "$@"
