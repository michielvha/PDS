configure_admin (){
  local SSH_PUBLIC_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJuz/p0uJEULyptuR7US4GnGmCziaKLQsxYO5VyAx+Oa sysadmin@mvha.eu.org"
  # TODO: Check if user already exists before creating
  # Create the user and set the public key for SSH authentication
  echo "==> Creating user and setting up SSH public key..."
  sudo useradd -m -s /bin/bash "$USER_NAME" #TODO: change to zsh ?
  sudo mkdir -p /home/"$USER_NAME"/.ssh
  echo "$SSH_PUBLIC_KEY" | sudo tee /home/"$USER_NAME"/.ssh/authorized_keys
  sudo chown -R "$USER_NAME":"$USER_NAME" /home/"$USER_NAME"/.ssh
  sudo chmod 700 /home/"$USER_NAME"/.ssh
  sudo chmod 600 /home/"$USER_NAME"/.ssh/authorized_keys
  # Add the user to the sudo group
  echo "==> Adding $USER_NAME to the sudo group..."
  sudo usermod -aG sudo "$USER_NAME"
  echo "==> Adding sourcing of pds main functions for $USER_NAME."
  echo "source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/module/install.sh)" >> /home/"$USER_NAME"/.bashrc
  echo "User $USER_NAME created, SSH key added, user added to sudo group and bashrc modified."
}
