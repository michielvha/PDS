#!/bin/bash
# shellcheck disable=SC2296
# Common shell configuration functions
# This module contains functions for setting up and configuring ZSH shell environments
# Usage: source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/common/shell/zsh.sh)

# Function: install_zi
# Description: Installs and configures Zi, a package manager for ZSH
install_zi() {
    # Check if git is installed
    if ! command -v git &> /dev/null; then
        read -rp "Git is not installed. Install it now? (y/n): " choice
        [[ "$choice" =~ ^[Yy]$ ]] || { echo "Git is required. Exiting."; return 1; }

        { sudo apt update -y && sudo apt install -y git; } || { echo "Failed to install Git. Install it manually."; return 1; }
    fi

    # Install Zi
    sudo mkdir -p /usr/local/share/zi ~/.config/zi
    sudo git clone --depth=1 https://github.com/z-shell/zi /usr/local/share/zi
    echo "Zi installed successfully."
}

# Function: configure_zsh
# Description: Configures ZSH using Zi with plugins and settings for an enhanced shell experience
# TODO: Move to .zshrc file in this repository and create a function to add it to the /etc/zshrc file from github raw url, like we are doing in `set_bashrc`.
configure_zsh() {
  cat <<'EOF' | sudo tee ~/.zshrc  # ~/.p10k.zsh/etc/zshrc
source /usr/local/share/zi/zi.zsh

# --- Theme stuff ---
# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

zi light romkatv/powerlevel10k

[[ ! -f ~/.p10k.zsh ]] || source  ~/.p10k.zsh #import p10k config

### --- Plugins ---
zi light zsh-users/zsh-syntax-highlighting
zi light zsh-users/zsh-history-substring-search
# zi light zsh-users/zsh-autosuggestions # seems to conflict with zsh-autocomplete
# zi light zsh-users/zsh-completions # This plugin is not needed, as we use zsh-autocomplete instead.
zi light agkozak/zsh-z # Jump quickly to directories that you have visited "frecently." A native Zsh port of z.sh with added features. 

# Installs stuff in ~/zi/plugins that needs to be manually sourced.
zi light ohmyzsh/ohmyzsh
zi snippet OMZP::docker
zi snippet OMZP::history
zi snippet OMZP::git

### --- Autocomplete ---
# zi light marlonrichert/zsh-autocomplete
# zstyle ':autocomplete:*' default-context history-incremental-search-backward
# zstyle ':autocomplete:*' min-input 1
# setopt HIST_FIND_NO_DUPS
zi light michielvha/zsh-readline

# --- Enable kubectl autocompletion for zsh ---
#autoload -Uz compinit && compinit # zi enables this automatically.
if (( $+commands[kubectl] )); then
  # Only source if compdef is defined (meaning completion system is active)
  if (( $+functions[compdef] )); then
     source <(kubectl completion zsh)
     alias k='kubectl'
     compdef __start_kubectl k
  fi
fi

# --- Various ---
# TODO: 'neofetch' here will trigger p10k config error if ran before prompt is set. we'd have to wrap it in a precmd hook. as shown below.

alias knr='kubectl get pods --field-selector=status.phase!=Running'
EOF

  # this configures zsh for all new users, first create this config then create the new user. Point it to global config.
  cat <<'EOF' | sudo tee /etc/skel/.zshrc
source /etc/zshrc
EOF

cp ~/.zshrc /etc/zshrc
}
#TODO: Auto complete is not working in zsh, figure out why. Has to do with zsh-autocomplete, we need to figure out a way to have zsh completion work together with this plugin.
# use this to fix p10k warning when calling neofetch in .zshrc
# autoload -Uz add-zsh-hook
# add-zsh-hook precmd run_neofetch

# run_neofetch() {
#   command neofetch
# }


# Function: set_default_zsh
# Description: Sets ZSH as the default shell for the current user
set_default_zsh() {
    sudo chsh -s "$(which zsh)" "$(whoami)"
}

# Function: install_nerd_fonts
# Description: Install the recommended fonts for Powerlevel10k and configure GNOME Terminal to use them
install_nerd_fonts() {
    echo "Installing MesloLGS NF font for Powerlevel10k..."

    # Ensure dependencies are installed (wget, fontconfig)
    local dependencies_met=true
    if ! command -v wget &> /dev/null; then
        echo "wget not found."
        dependencies_met=false
    fi
    if ! command -v fc-cache &> /dev/null; then
        echo "fontconfig (fc-cache) not found."
        dependencies_met=false
    fi

    if [ "$dependencies_met" = false ]; then
        echo "Attempting to install missing dependencies..."
        if sudo apt update && sudo apt install -y wget fontconfig; then
            echo "Dependencies installed successfully."
        else
            echo "Failed to install missing dependencies (wget, fontconfig). Please install them manually and re-run."
            return 1
        fi
    fi

    local font_dir="/usr/local/share/fonts/MesloLGSNF"
    local font_urls=(
        "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf"
        "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold.ttf"
        "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Italic.ttf"
        "https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold%20Italic.ttf"
    )

    echo "Creating font directory: $font_dir"
    sudo mkdir -p "$font_dir"

    echo "Downloading MesloLGS NF fonts..."
    for url in "${font_urls[@]}"; do
        local filename
        filename=$(basename "$url") # Extracts the filename from the URL
        if [ ! -f "$font_dir/$filename" ]; then
            echo "Downloading $filename..."
            if ! sudo wget --quiet -O "$font_dir/$filename" "$url"; then
                echo "Failed to download $filename. Please check URL/network."
                # Consider removing the partially downloaded file if any: sudo rm -f "$font_dir/$filename"
            fi
        else
            echo "$filename already exists in $font_dir. Skipping download."
        fi
    done

    echo "Updating font cache..."
    if ! sudo fc-cache -fv; then
        echo "Warning: fc-cache command failed. Font cache might not be updated correctly."
    fi

    echo "Configuring GNOME Terminal to use MesloLGS NF..."
    if command -v gsettings &> /dev/null; then
        local default_profile_uuid
        # Get the default profile UUID
        default_profile_uuid=$(gsettings get org.gnome.Terminal.ProfilesList default 2>/dev/null | tr -d "'")

        # If default is not found, try to get the first profile from the list as a fallback
        if [ -z "$default_profile_uuid" ]; then
            echo "Could not determine default GNOME Terminal profile UUID directly."
            local available_profiles_list
            available_profiles_list=$(gsettings get org.gnome.Terminal.ProfilesList list 2>/dev/null)
            # Regex to extract the first UUID from a list like "['uuid1', 'uuid2']" or "@as ['uuid1', 'uuid2']"
            if [[ "$available_profiles_list" =~ '([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})' ]]; then
                default_profile_uuid=${BASH_REMATCH[1]}
                echo "Using the first available profile UUID: $default_profile_uuid as a fallback."
            fi
        fi
        
        if [ -z "$default_profile_uuid" ]; then
            echo "No GNOME Terminal profile UUID could be identified. Please set the font manually in Terminal preferences."
        else
            # Construct the GSettings path for the profile. This is a common path structure.
            local profile_gsettings_path="org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$default_profile_uuid/"
            
            echo "Attempting to set font for profile using GSettings path: $profile_gsettings_path"

            # Verify the path is valid by trying to read a known key (e.g., visible-name)
            if gsettings get "$profile_gsettings_path" visible-name > /dev/null 2>&1; then
                gsettings set "$profile_gsettings_path" use-system-font false
                gsettings set "$profile_gsettings_path" font 'MesloLGS NF Regular 13' # Using a common default size
                echo "GNOME Terminal font set to 'MesloLGS NF Regular 11' for profile UUID '$default_profile_uuid'."
                echo "You may need to restart your terminal or open a new tab/window to see the changes."
            else
                echo "Warning: Could not access GNOME Terminal profile at $profile_gsettings_path."
                echo "This could be due to a different GSettings schema or path structure on your system (e.g., non-legacy profiles or different naming)."
                echo "Please configure your terminal font manually to 'MesloLGS NF Regular' in Terminal preferences."
            fi
        fi
    else
        echo "gsettings command not found. Cannot configure GNOME Terminal automatically."
        echo "Please configure your terminal font manually to 'MesloLGS NF Regular' in Terminal preferences."
    fi

    echo "MesloLGS NF font installation and GNOME Terminal configuration attempt complete."
    echo "If the font does not appear correctly, please ensure 'MesloLGS NF Regular' is selected in your terminal's profile settings."
}
