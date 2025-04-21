#!/bin/bash
# Function: This script sources all shell files directly from GitHub repository's raw content
# Usage: source source_all.sh [branch_or_tag]
# Default branch is main if not specified
# source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/source_all.sh)


# Define the main function that sources all GitHub shell files
source_github_shell_files() {
    # Repository information
    local GITHUB_USER="michielvha"
    local GITHUB_REPO="PDS"
    local BRANCH_OR_TAG="${1:-main}"  # Use the first argument as branch/tag or default to main

    # Base URL for raw content
    local BASE_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${BRANCH_OR_TAG}"

    # ANSI color codes for output
    local GREEN='\033[0;32m'
    local BLUE='\033[0;34m'
    local NC='\033[0m' # No Color

    echo -e "${BLUE}Sourcing shell files from ${GITHUB_USER}/${GITHUB_REPO} (${BRANCH_OR_TAG})${NC}"

    # Function to source a file from GitHub
    source_from_github() {
        local file_path=$1
        local full_url="${BASE_URL}/${file_path}"
        
        echo -e "${BLUE}Sourcing: ${file_path}${NC}"
        
        # Download and source the file
        local content=$(curl -sSL "${full_url}")
        if [ $? -eq 0 ] && [ -n "${content}" ]; then
            # Using eval to source the content directly
            eval "${content}"
            echo -e "${GREEN}✓ Successfully sourced: ${file_path}${NC}"
        else
            echo -e "\033[0;31m✗ Failed to source: ${file_path}\033[0m"
        fi
    }

    # Source common shell utilities
    source_from_github "bash/common/shell/zsh.sh"

    # Source cloud utilities
    source_from_github "bash/common/cloud/aws.sh"
    source_from_github "bash/common/cloud/azure.sh"

    # Source software utilities
    source_from_github "bash/common/software/go.sh"
    source_from_github "bash/common/software/packer.sh"

    # Source other utility functions
    source_from_github "bash/common/utils/get_latest_github_binary.sh"

    # Source module files
    source_from_github "bash/module/public.sh"
    source_from_github "bash/module/utils.sh"
    source_from_github "bash/module/sysadmin.sh"

    echo -e "${GREEN}All files have been sourced successfully.${NC}"
}

source_github_shell_files "$@"