#!/bin/bash
# Zsh uses %x for the defining source file; Bash uses BASH_SOURCE.
# shellcheck disable=SC2296
# Zi installation and shell configuration shared by workstations and images.

install_zi() {
    if [[ -r /usr/local/share/zi/zi.zsh ]]; then
        return 0
    fi
    if ! command -v git >/dev/null 2>&1; then
        printf '%s\n' 'install_zi requires git; install it with the image base packages.' >&2
        return 1
    fi
    if [[ -e /usr/local/share/zi ]]; then
        printf '%s\n' 'Refusing to overwrite /usr/local/share/zi: zi.zsh is missing.' >&2
        return 1
    fi
    sudo git clone --depth=1 https://github.com/z-shell/zi /usr/local/share/zi
}

# Preserve existing configuration once before installing the maintained copy.
_pds_install_zsh_config() {
    local source_file="$1" destination="$2"
    if [[ -e "$destination" ]] && ! cmp -s -- "$source_file" "$destination"; then
        if [[ ! -e "${destination}.pds-backup" ]]; then
            sudo cp -p -- "$destination" "${destination}.pds-backup" || return
        fi
    fi
    sudo install -m 0644 -- "$source_file" "$destination"
}

configure_zsh() (
    local config_dir work loader
    config_dir="$(dirname -- "${BASH_SOURCE[0]:-${(%):-%x}}")/../../config"
    if [[ ! -d "$HOME" ]]; then
        printf '%s\n' 'configure_zsh requires an existing HOME directory.' >&2
        return 1
    fi
    work="$(mktemp -d)" || return 1
    trap 'rm -rf -- "$work"' EXIT
    # Fetch standalone bootstrap assets only at this explicit call.
    if [[ ! -r "$config_dir/zshrc" || ! -r "$config_dir/.p10k.zsh" ]]; then
        config_dir="$work"
        curl -fsSL "https://raw.githubusercontent.com/michielvha/PDS/${PDS_REF:-main}/bash/config/zshrc" -o "$config_dir/zshrc" || return 1
        curl -fsSL "https://raw.githubusercontent.com/michielvha/PDS/${PDS_REF:-main}/bash/config/.p10k.zsh" -o "$config_dir/.p10k.zsh" || return 1
    fi
    loader="$work/loader"
    printf '%s\n' 'source /etc/zshrc' > "$loader" || return 1
    sudo install -d /etc/skel || return 1
    _pds_install_zsh_config "$config_dir/zshrc" /etc/zshrc || return 1
    _pds_install_zsh_config "$loader" /etc/skel/.zshrc || return 1
    _pds_install_zsh_config "$config_dir/.p10k.zsh" /etc/skel/.p10k.zsh || return 1
    _pds_install_zsh_config "$loader" "$HOME/.zshrc" || return 1
    _pds_install_zsh_config "$config_dir/.p10k.zsh" "$HOME/.p10k.zsh" || return 1
    sudo chown "$(id -u):$(id -g)" "$HOME/.zshrc" "$HOME/.p10k.zsh"
)

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
            if [[ "$available_profiles_list" =~ ([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}) ]]; then
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
