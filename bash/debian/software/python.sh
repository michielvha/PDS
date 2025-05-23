#!/bin/bash
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/debian/software/python.sh) `

# Function: set_venv
# Description: Quickly sets up a Python virtual environment in the current directory
set_venv() {
    echo "🌐 Setting up Python virtual environment..."
    python3 -m venv .venv
    source .venv/bin/activate
}