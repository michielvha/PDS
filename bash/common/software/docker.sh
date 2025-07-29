#!/bin/bash
# shellcheck disable=SC2016
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/common/software/docker.sh) `

# Function: refresh_docker_compose
# Description: Remove a container tagged with latest to be sure the container is repulled and relaunch the docker compse stack.
refresh_docker_compose(){

  # docker compose down
  # Find the image based on the name, so get the id from the name and remove it
  # docker compose up -d

}
