#!/bin/bash
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/common/shell/set_bashrc.sh) `

# Function: set_bashrc
# Description: Merges .bashrc configuration from PDS repository to the current user's bash configuration.
# Usage: set_bashrc
set_bashrc(){
    local bashrc_url="https://raw.githubusercontent.com/michielvha/PDS/main/bash/common/shell/.bashrc"
    local user_bashrc="$HOME/.bashrc"
    local pds_marker="# PDS Configuration - DO NOT EDIT BELOW THIS LINE"
    local pds_end_marker="# PDS Configuration - END"
    
    echo "Setting up .bashrc configuration from PDS repository..."
    
    # Create backup of existing .bashrc if it exists
    if [[ -f "$user_bashrc" ]]; then
        echo "Creating backup of existing .bashrc..."
        cp "$user_bashrc" "$user_bashrc.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    # Remove any existing PDS configuration to avoid duplicates
    if [[ -f "$user_bashrc" ]] && grep -q "$pds_marker" "$user_bashrc"; then
        echo "Removing existing PDS configuration..."
        sed -i "/$pds_marker/,/$pds_end_marker/d" "$user_bashrc"
    fi
    
    # Download and append PDS configuration
    echo "Downloading PDS .bashrc configuration..."
    pds_config=$(curl -fsSL "$bashrc_url" | grep -v '^#!/bin/bash' | grep -v '^# shellcheck')
    curl_status=$?
    
    if [[ $curl_status -eq 0 ]]; then
        {
            echo ""
            echo "$pds_marker"
            echo "$pds_config"
            echo "$pds_end_marker"
        } >> "$user_bashrc"
        
        echo "✅ PDS .bashrc configuration successfully added to $user_bashrc"
        echo "💡 Run 'source ~/.bashrc' or start a new terminal session to apply changes"
    else
        echo "❌ Failed to download or add PDS configuration"
        return 1
    fi
}
