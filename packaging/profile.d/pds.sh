#!/bin/sh
# PDS Functions Auto-loader for interactive shells
# This script is placed in /etc/profile.d/ to automatically load PDS functions
# Supports both Bash and Zsh shells

# Only load for interactive shells (bash or zsh)
# Profile.d scripts are sourced for login shells, which are interactive
# Check for shell type: bash or zsh
if [ -n "${BASH_VERSION:-}" ]; then
    # Bash: check if interactive (profile.d scripts are sourced for login shells)
    # Use case statement for POSIX compatibility when checking $- for 'i'
    case $- in
        *i*) is_interactive=1 ;;
    esac
elif [ -n "${ZSH_VERSION:-}" ]; then
    # Zsh: profile.d scripts are sourced for login shells (interactive)
    is_interactive=1
fi

if [ -n "${is_interactive:-}" ]; then
    # Allow users to opt-out by setting PDS_DISABLE=1
    if [ -z "${PDS_DISABLE:-}" ]; then
        # Check if PDS is installed and load it
        if [ -r /usr/share/pds/init.sh ]; then
            # shellcheck disable=SC1091
            if . /usr/share/pds/init.sh 2>/dev/null; then
                # Show a brief welcome message on first load in a session
                if [ -z "${PDS_LOADED:-}" ]; then
                    echo "PDS Functions loaded! Type 'pds help' for available commands."
                    export PDS_LOADED=1
                fi
            else
                echo "Warning: Failed to load PDS functions" >&2
            fi
        fi
    fi
fi
