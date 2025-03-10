#!/bin/bash
# Download and source all modules
# usage: quickly source this module with the following command:
# ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/bootstrap.sh) `
# ------------------------------------------------------------------------------------------------

MODULE_PATH="$HOME/.bash_modules"
REPO_URL="https://raw.githubusercontent.com/michielvha/PDS/main/bash/module"
MODULES=("install.sh" "sysadmin.sh" "rke2.sh" "public.sh" "utils.sh")

mkdir -p "$MODULE_PATH"

for module in "${MODULES[@]}"; do
    curl -fsSL "$REPO_URL/$module" -o "$MODULE_PATH/$module" || { echo "Failed to download $module"; exit 1; }
    source "$MODULE_PATH/$module"
done


show_help() {
    echo "Available Commands:"

    declare -F | awk '{print $3}' | while read -r cmd; do
        # Skip internal Bash functions
        case "$cmd" in
            _*|__*|show_help|log_*|gawk*|*quote*) continue ;;  # Ignore functions starting with "_" or "__" + logging helpers
        esac

        # Extract function description from function body
        desc=$(declare -f "$cmd" | grep -m1 -E '^\s*# description:' | sed 's/# description: //')

        # Print with or without description
        if [[ -n "$desc" ]]; then
            echo "  $cmd - $desc"
        else
            echo "  $cmd"
        fi
    done
}



## upgrade system
#full_upgrade
#
## set locale
#
## install software
#
## install & configure zsh
#install_zsh
#configure_zsh
#
## extra system config
#update_system_cron_entry