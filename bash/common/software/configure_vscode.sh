#!/bin/bash
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/common/software/configure_vscode.sh) `

# Function: configure_vscode_terminal_font
# Description: Configures VS Code/Cursor terminal to use MesloLGS NF font (nerd font) for the terminal only.
#              This does not affect the editor font, only the integrated terminal font.
#              Supports VS Code, Code (OSS), and Cursor installations.
install_meslolgs_nf_font() {
    local font_dir="$HOME/.local/share/fonts"
    local base_url="https://github.com/romkatv/powerlevel10k-media/raw/master"
    local fonts=(
        "MesloLGS NF Regular.ttf"
        "MesloLGS NF Bold.ttf"
        "MesloLGS NF Italic.ttf"
        "MesloLGS NF Bold Italic.ttf"
    )
    
    echo "📥 Installing MesloLGS NF font..."
    
    # Create font directory if it doesn't exist
    mkdir -p "$font_dir"
    
    # Download each font file
    local downloaded=0
    for font in "${fonts[@]}"; do
        local font_file="$font_dir/$font"
        local font_url="$base_url/${font// /%20}"
        
        if [[ -f "$font_file" ]]; then
            echo "ℹ️  Font file already exists: $font"
            continue
        fi
        
        echo "   Downloading $font..."
        if command -v curl &> /dev/null; then
            if curl -fsSL -o "$font_file" "$font_url"; then
                ((downloaded++))
                echo "   ✅ Downloaded $font"
            else
                echo "   ❌ Failed to download $font"
                rm -f "$font_file"
                return 1
            fi
        elif command -v wget &> /dev/null; then
            if wget -q --show-progress -O "$font_file" "$font_url"; then
                ((downloaded++))
                echo "   ✅ Downloaded $font"
            else
                echo "   ❌ Failed to download $font"
                rm -f "$font_file"
                return 1
            fi
        else
            echo "   ❌ Neither curl nor wget is available. Cannot download fonts."
            return 1
        fi
    done
    
    # Update font cache
    if [[ $downloaded -gt 0 ]]; then
        echo "🔄 Updating font cache..."
        if command -v fc-cache &> /dev/null; then
            fc-cache -f "$font_dir" &> /dev/null
            echo "✅ Font cache updated"
        fi
        
        # Verify installation
        if command -v fc-list &> /dev/null; then
            if fc-list | grep -qi "MesloLGS NF"; then
                echo "✅ MesloLGS NF font installed successfully!"
                return 0
            else
                echo "⚠️  Font files installed but may not be detected yet."
                echo "   You may need to log out and log back in, or restart your system."
                return 0
            fi
        else
            echo "✅ Font files installed to $font_dir"
            echo "   Note: fc-list not available, cannot verify installation."
            return 0
        fi
    else
        echo "✅ All font files already installed"
        return 0
    fi
}

configure_vscode_terminal_font() {
    local font_name="MesloLGS NF"
    local settings_files=()
    local settings_updated=false
    
    # Check if font is installed, install if not
    if command -v fc-list &> /dev/null; then
        if ! fc-list | grep -qi "MesloLGS NF"; then
            echo "⚠️  MesloLGS NF font not found. Installing..."
            if ! install_meslolgs_nf_font; then
                echo "❌ Failed to install MesloLGS NF font."
                return 1
            fi
        fi
    else
        # fc-list not available, try installing anyway (user might need to restart)
        echo "⚠️  Cannot verify font installation (fc-list not available). Attempting installation..."
        if ! install_meslolgs_nf_font; then
            echo "❌ Failed to install MesloLGS NF font."
            return 1
        fi
    fi
    
    # Check for VS Code/Cursor settings files (both regular and OSS versions)
    # Also check if directories exist (settings.json might not exist yet)
    if [[ -d "$HOME/.config/Code/User" ]]; then
        settings_files+=("$HOME/.config/Code/User/settings.json")
    fi
    
    if [[ -d "$HOME/.config/Code - OSS/User" ]]; then
        settings_files+=("$HOME/.config/Code - OSS/User/settings.json")
    fi
    
    if [[ -d "$HOME/.config/Cursor/User" ]]; then
        settings_files+=("$HOME/.config/Cursor/User/settings.json")
    fi
    
    if [[ ${#settings_files[@]} -eq 0 ]]; then
        echo "⚠️  VS Code/Cursor configuration directory not found."
        echo "   Please open VS Code or Cursor at least once to create the configuration directory, then run this function again."
        return 1
    fi
    
    echo "🔧 Configuring VS Code/Cursor terminal font to use: $font_name"
    
    for settings_file in "${settings_files[@]}"; do
        local settings_dir
        settings_dir=$(dirname "$settings_file")
        
        # Create directory if it doesn't exist
        mkdir -p "$settings_dir"
        
        # Check if settings.json exists, create it if not
        if [[ ! -f "$settings_file" ]]; then
            echo "{}" > "$settings_file"
        fi
        
        # Check if jq is available for JSON manipulation
        if command -v jq &> /dev/null; then
            # Use jq to update the settings file
            local current_font
            current_font=$(jq -r '.["terminal.integrated.fontFamily"] // empty' "$settings_file" 2>/dev/null)
            
            if [[ "$current_font" == "$font_name" ]]; then
                echo "ℹ️  Terminal font already set to '$font_name' in $(basename "$settings_dir")"
            else
                # Update the settings file with jq
                jq --arg font "$font_name" '.["terminal.integrated.fontFamily"] = $font' "$settings_file" > "${settings_file}.tmp" && mv "${settings_file}.tmp" "$settings_file"
                echo "✅ Updated terminal font to '$font_name' in $(basename "$settings_dir")"
                settings_updated=true
            fi
        else
            # Fallback: use sed/grep for basic JSON manipulation (less robust but works without jq)
            if grep -q '"terminal.integrated.fontFamily"' "$settings_file" 2>/dev/null; then
                # Update existing setting
                if grep -q "\"terminal.integrated.fontFamily\".*\"$font_name\"" "$settings_file" 2>/dev/null; then
                    echo "ℹ️  Terminal font already set to '$font_name' in $(basename "$settings_dir")"
                else
                    # Replace the existing font setting
                    sed -i "s|\"terminal.integrated.fontFamily\".*|\"terminal.integrated.fontFamily\": \"$font_name\",|g" "$settings_file"
                    echo "✅ Updated terminal font to '$font_name' in $(basename "$settings_dir")"
                    settings_updated=true
                fi
            else
                # Add new setting
                local temp_file
                temp_file=$(mktemp)
                
                # Read the file and add the setting
                if [[ -s "$settings_file" ]] && [[ "$(cat "$settings_file" | tr -d '[:space:]')" != "{}" ]]; then
                    # File has content, add comma and new setting
                    # Escape special characters in font name for sed
                    local escaped_font
                    escaped_font=$(printf '%s\n' "$font_name" | sed 's/[[\.*^$()+?{|]/\\&/g')
                    # Use $'\n' for newlines (bash-specific, which this script is)
                    sed '$s/}$/,\'$'\n''    "terminal.integrated.fontFamily": "'"$escaped_font"'"\'$'\n''}/' "$settings_file" > "$temp_file"
                else
                    # Empty file or just {}, create new JSON
                    cat > "$temp_file" << EOF
{
    "terminal.integrated.fontFamily": "$font_name"
}
EOF
                fi
                
                mv "$temp_file" "$settings_file"
                echo "✅ Added terminal font setting '$font_name' to $(basename "$settings_dir")"
                settings_updated=true
            fi
        fi
    done
    
    if [[ "$settings_updated" == true ]]; then
        echo ""
        echo "✅ VS Code/Cursor terminal font configured successfully!"
        echo "   Please restart VS Code/Cursor or reload the window to see the changes."
        echo "   (Press Ctrl+Shift+P and type 'Reload Window')"
    else
        echo ""
        echo "✅ VS Code/Cursor terminal font is already configured correctly."
    fi
}

