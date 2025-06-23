#!/bin/bash
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/debian/software/install_anything_llm.sh) `

# Function: install_anything_llm
# Description: Downloads and runs the Anything LLM Docker container
# Reference: https://github.com/Mintplex-Labs/anything-llm/blob/master/docker/HOW_TO_USE_DOCKER.md
install_anything_llm() {
    pre_checks

    echo "Cloning Anything LLM repository..."
    git clone https://github.com/Mintplex-Labs/anything-llm
    cd anything-llm/docker || return
    cp .env.example .env
    echo "Starting Docker containers..."
    docker compose up -d
}

pre_checks(){
    # Check if Docker is installed
    command -v docker &> /dev/null || { echo "Docker is not installed. Please install first."; exit 1; }

    # Check if Docker Compose is installed
    command -v docker compose &> /dev/null || { echo "Docker Compose is not installed. Please install first."; exit 1; }

    # Check if Git is installed
    command -v git &> /dev/null || { echo "Git is not installed. Please install first."; exit 1; }
}
