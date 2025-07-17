#!/bin/bash
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/common/shell/create_admin.sh) `

# Function: configure_admin
# Description: Configures a new admin user with SSH access and sudo privileges.
# Usage: configure_admin <username>
configure_admin(){

  # environment configuration
  source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/common/utils/detect_distro.sh)
  local SSH_PUBLIC_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJuz/p0uJEULyptuR7US4GnGmCziaKLQsxYO5VyAx+Oa sysadmin@mvha.eu.org"
  local ADMIN="$1"
  local distro
  distro=$(detect_distro)

  # Check if ADMIN variable is set
  [[ -z "$ADMIN" ]] && { echo "Usage: configure_admin <username>"; return 1; }

  # Check if user already exists before creating  
  id "$ADMIN" &>/dev/null && echo "👤 User $ADMIN already exists, skipping user creation..." || (echo "👤 Creating admin user $ADMIN..." && sudo useradd -m -s /bin/bash "$ADMIN")
  
  # Create SSH directory (idempotent)
  echo "🔑 Setting up SSH public key..."
  sudo mkdir -p /home/"$ADMIN"/.ssh
  # Add SSH public key to authorized_keys
  echo "$SSH_PUBLIC_KEY" | sudo tee /home/"$ADMIN"/.ssh/authorized_keys
  
  # Set permissions for SSH directory and authorized_keys file
  sudo chown -R "$ADMIN":"$ADMIN" /home/"$ADMIN"/.ssh
  sudo chmod 700 /home/"$ADMIN"/.ssh
  sudo chmod 600 /home/"$ADMIN"/.ssh/authorized_keys

  # Add the user to the sudo group
  echo "🔐 Adding $ADMIN to the sudo group..."
  if [[ "$distro" == "debian" ]]; then
    sudo usermod -aG sudo "$ADMIN"
  elif [[ "$distro" == "rhel" ]]; then
    sudo usermod -aG wheel "$ADMIN"
  else
    echo "❌ Unsupported distribution: $distro"
    return 1
  fi

  # Configure .bashrc
  # echo "🔧 Adding sourcing of pds main functions for $ADMIN."
  # echo "source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/module/install.sh)" >> /home/"$ADMIN"/.bashrc
  # echo "User $ADMIN created, SSH key added, user added to sudo group and bashrc modified."
}
