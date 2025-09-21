#!/bin/bash
# PDS Functions Auto-loader for interactive Bash shells
# This script is placed in /etc/profile.d/ to automatically load PDS functions

# Only load for interactive Bash shells
if [ -n "${BASH_VERSION:-}" ] && [[ $- == *i* ]]; then
    # Allow users to opt-out by setting PDS_DISABLE=1
    if [ -z "${PDS_DISABLE:-}" ]; then
        # Check if PDS is installed and load it
        if [ -r /usr/share/pds/init.sh ]; then
            # shellcheck disable=SC1091
            if source /usr/share/pds/init.sh 2>/dev/null; then
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
