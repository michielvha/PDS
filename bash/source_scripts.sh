#!/bin/bash
# Purpose: Sources all Debian system scripts from your local repository
# Usage: source ./source_scripts.sh
# ------------------------------------------------------------------------------------------------------------------------------------------------

source_local_scripts() {
  local BASE_DIR="$(pwd)"
  local FOUND_SCRIPTS=0
  local SOURCED_SCRIPTS=0
  
  echo "🔍 Finding scripts in the local directory..."
  
  # Find all .sh files recursively
  while IFS= read -r script; do
    # Skip the source script itself
    if [[ "$script" == *"source_scripts.sh"* ]]; then
      continue
    fi
    
    FOUND_SCRIPTS=$((FOUND_SCRIPTS + 1))
    echo "  🔄 Sourcing $script..."
    
    # Source the script
    source "$script" 2>/dev/null
    
    # Check if sourcing was successful
    if [ $? -eq 0 ]; then
      echo "  ✅ Successfully sourced $script"
      SOURCED_SCRIPTS=$((SOURCED_SCRIPTS + 1))
    else
      echo "  ⚠️  Warning: $script contained errors but was partially sourced"
    fi
  done < <(find "$BASE_DIR" -type f -name "*.sh" | sort)
  
  echo "✅ Sourcing complete: $SOURCED_SCRIPTS of $FOUND_SCRIPTS scripts were sourced"
  
  # List all available functions
  echo ""
  echo "📋 Available functions from sourced scripts:"
  declare -F | grep -v "^declare -f _" | cut -d' ' -f3 | sort | grep -v "source_local_scripts" | while read func; do
    echo "  - $func"
  done
}

# Execute the function when this script is sourced
source_local_scripts