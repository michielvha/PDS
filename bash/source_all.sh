#!/bin/bash
# Purpose: Dynamically sources all scripts from the repository by querying the GitHub API
# Usage: Quickly source this script with the following command:
# ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/source_all.sh) `
# ------------------------------------------------------------------------------------------------------------------------------------------------

source_all_scripts() {
  # GitHub repository information
  local REPO_OWNER="michielvha"
  local REPO_NAME="PDS"
  local BRANCH="main"
  local BASE_URL="https://raw.githubusercontent.com/$REPO_OWNER/$REPO_NAME/$BRANCH"
  local API_URL="https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/contents"
  
  echo "🔍 Finding scripts in the repository..."
  
  # Function to recursively process directories and find .sh files
  process_directory() {
    local path=$1
    local dir_url="$API_URL/$path"
    
    # If path is not empty, add trailing slash
    if [ ! -z "$path" ]; then
      dir_url="$API_URL/$path"
    fi
    
    # Get directory contents
    local dir_contents=$(curl -s "$dir_url")
    
    # Check if API limit reached
    if echo "$dir_contents" | grep -q "API rate limit exceeded"; then
      echo "❌ GitHub API rate limit exceeded. Please try again later."
      return 1
    fi
    
    # Process each item in the directory
    echo "$dir_contents" | grep -o '"type":"[^"]*","name":"[^"]*","path":"[^"]*"' | while read -r item; do
      local type=$(echo "$item" | grep -o '"type":"[^"]*' | cut -d'"' -f4)
      local path=$(echo "$item" | grep -o '"path":"[^"]*' | cut -d'"' -f4)
      
      if [ "$type" = "dir" ]; then
        # Recursively process subdirectory
        process_directory "$path"
      elif [ "$type" = "file" ] && [[ "$path" == *.sh ]]; then
        # Found a shell script
        process_script "$path"
      fi
    done
  }
  
  # Function to process a single script
  process_script() {
    local script_path=$1
    TOTAL_SCRIPTS=$((TOTAL_SCRIPTS + 1))
    
    # Skip excluded scripts
    for excluded in "${EXCLUDED_SCRIPTS[@]}"; do
      if [[ "$script_path" == *"$excluded" ]]; then
        echo "  ⏭️  Skipping $script_path (excluded)"
        return 0
      fi
    done
    
    echo "  🔄 Sourcing $script_path..."
    
    # Download script to temporary location
    local SCRIPT_URL="$BASE_URL/$script_path"
    local TMP_SCRIPT="$TMP_DIR/$(basename "$script_path")"
    
    # Download the script
    curl -fsSL "$SCRIPT_URL" -o "$TMP_SCRIPT" 2>/dev/null
    
    # Check if file exists and is not empty
    if [ -s "$TMP_SCRIPT" ]; then
      # Source the script
      source "$TMP_SCRIPT" 2>/dev/null
      
      # Check if sourcing was successful
      if [ $? -eq 0 ]; then
        echo "  ✅ Successfully sourced $script_path"
        SOURCED_SCRIPTS=$((SOURCED_SCRIPTS + 1))
      else
        echo "  ⚠️  Warning: $script_path contained errors but was partially sourced"
      fi
    else
      echo "  ❌ Failed to download $script_path"
    fi
  }
  
  # Variables for tracking scripts
  local EXCLUDED_SCRIPTS=("bootstrap.sh" "source_all.sh" "run.bat" "run.cmd")
  local TOTAL_SCRIPTS=0
  local SOURCED_SCRIPTS=0
  
  # Create temporary directory for downloaded scripts
  local TMP_DIR=$(mktemp -d)
  
  echo "📥 Starting to source scripts from $BASE_URL"
  
  # Start processing from root directory
  process_directory ""
  
  # Clean up temporary directory
  rm -rf "$TMP_DIR"
  
  echo "✅ Sourcing complete: $SOURCED_SCRIPTS of $TOTAL_SCRIPTS scripts were sourced"
  
  # List all available functions
  echo ""
  echo "📋 Available functions from sourced scripts:"
  declare -F | grep -v "^declare -f _" | cut -d' ' -f3 | sort | grep -v "source_all_scripts\|process_directory\|process_script" | while read func; do
    echo "  - $func"
  done
}

# Execute the function when this script is sourced
source_all_scripts