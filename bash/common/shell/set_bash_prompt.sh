#!/bin/bash
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/common/shell/set_bash_prompt.sh) `

# Function: set_bash_prompt
# Description: Installs the PDS bash prompt into its own standalone file and wires it into ~/.bashrc via a single guarded source line, so it never clobbers an existing distro .bashrc (Ubuntu/Fedora). Re-running is idempotent.
# Usage: set_bash_prompt
set_bash_prompt(){
    local prompt_url="https://raw.githubusercontent.com/michielvha/PDS/main/bash/common/shell/prompt.bash"
    local prompt_dir="$HOME/.config/pds"
    local prompt_file="$prompt_dir/prompt.bash"
    local user_bashrc="$HOME/.bashrc"
    local pds_marker="# PDS bash prompt"
    local source_line="[ -f \"$prompt_file\" ] && . \"$prompt_file\"  $pds_marker"

    echo "Installing PDS bash prompt..."

    # Download the standalone prompt snippet into its own file (never touches the rest of .bashrc)
    mkdir -p "$prompt_dir"
    if ! curl -fsSL "$prompt_url" -o "$prompt_file"; then
        echo "❌ Failed to download PDS prompt from $prompt_url"
        return 1
    fi
    echo "✅ Prompt saved to $prompt_file"

    # Wire it into .bashrc with a single guarded source line, only if not already present
    if [[ -f "$user_bashrc" ]] && grep -qF "$pds_marker" "$user_bashrc"; then
        echo "ℹ️  Source line already present in $user_bashrc - left untouched"
    else
        printf '\n%s\n' "$source_line" >> "$user_bashrc"
        echo "✅ Added source line to $user_bashrc"
    fi

    echo "💡 Run 'source ~/.bashrc' or start a new terminal session to apply changes"
}
