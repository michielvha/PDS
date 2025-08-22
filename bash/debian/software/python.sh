#!/bin/bash
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/debian/software/python.sh) `

# Function: set_venv
# Description: Quickly sets up a Python virtual environment in the current directory
set_venv() {
    echo "🌐 Setting up Python virtual environment..."
    python3 -m venv .venv
    # shellcheck disable=SC1091 # .venv/bin/activate is created by python3 -m venv
    source .venv/bin/activate # this command ends the script..

    # figure out how to handle this when the function gets interrupted
    pip install -r requirements.txt
    echo "✅ Python virtual environment set up successfully."
}