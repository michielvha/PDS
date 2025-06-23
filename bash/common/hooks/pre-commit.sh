#!/bin/bash
# Pre commit hooks
# This module contains pre-commit hooks for git
# Usage: source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/common/hooks/pre-commit.sh)

# Function: pre_commit_hook
# Description: Pre-commit hook that automatically formats Go code using gofumpt
pre_commit_hook_gofumpt() {
    echo "🔧 Running pre-commit hook: gofumpt"
    # Check if gofumpt is installed
    if ! command -v gofumpt &> /dev/null; then
        echo "ERROR: gofumpt not found"
        echo "Please install it with: go install mvdan.cc/gofumpt@latest"
        exit 1
    fi

    REPO_ROOT=$(git rev-parse --show-toplevel) # get repo root directory
    cd "$REPO_ROOT" || exit 1
    echo "🪄 Running gofumpt in $(pwd)"
    gofumpt -w .

    # Stage the formatted files if any were changed
    git diff --name-only --diff-filter=M | grep '\.go$' | xargs -I{} git add {}

    echo "🧹 Go code formatting complete!"
}