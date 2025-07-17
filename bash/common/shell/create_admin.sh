#!/bin/bash
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/common/shell/set_sudo_nopasswd.sh) `

# Function: set_sudo_nopasswd
# Description: Setup passwordless sudo for a user
configure_admin (){
  local SSH_PUBLIC_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJuz/p0uJEULyptuR7US4GnGmCziaKLQsxYO5VyAx+Oa sysadmin@mvha.eu.org"
  local ADMIN="$1"

  if [[ -z "$ADMIN" ]]; then
    echo "Usage: configure_admin <username>"
    return 1
  fi

  # TODO: Check if user already exists before creating
  # Create the user and set the public key for SSH authentication
  echo "👤 Creating admin user and setting up SSH public key..."
  sudo useradd -m -s /bin/bash "$ADMIN" #TODO: change to zsh ?
  sudo mkdir -p /home/"$ADMIN"/.ssh

  echo "$SSH_PUBLIC_KEY" | sudo tee /home/"$ADMIN"/.ssh/authorized_keys
  sudo chown -R "$ADMIN":"$ADMIN" /home/"$ADMIN"/.ssh
  sudo chmod 700 /home/"$ADMIN"/.ssh
  sudo chmod 600 /home/"$ADMIN"/.ssh/authorized_keys

  # Add the user to the sudo group
  echo "🔐 Adding $ADMIN to the sudo group..."
  sudo usermod -aG sudo "$ADMIN"

  # Configure .bashrc
  # echo "🔧 Adding sourcing of pds main functions for $ADMIN."
  # echo "source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/module/install.sh)" >> /home/"$ADMIN"/.bashrc
  # echo "User $ADMIN created, SSH key added, user added to sudo group and bashrc modified."
}
