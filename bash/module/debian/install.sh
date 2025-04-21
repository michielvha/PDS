# install librewolf
install_librewolf() {
    sudo apt update && sudo apt install extrepo -y
    sudo extrepo enable librewolf
    sudo apt update && sudo apt install librewolf -y
}

setup_gnome_extras() {
  echo "🔧 Installing GNOME Tweaks and useful shell extensions..."

  # Base tools
  sudo apt update
  sudo apt install -y gnome-tweaks gnome-shell-extensions gnome-shell-extension-prefs curl jq

  # Create temp dir
  tmp_dir=$(mktemp -d)
  cd "$tmp_dir" || exit 1

  # Helper to install extensions by UUID from extensions.gnome.org
  install_extension() {
    local uuid=$1
    local name=$2
    local version
    version=$(gnome-shell --version | awk '{print $3}' | cut -d '.' -f1-2)
    echo "⬇️  Installing $name ($uuid)"
    curl -s "https://extensions.gnome.org/extension-data/${uuid}.shell-extension.zip" \
      -o "${uuid}.zip"
    mkdir -p "$HOME/.local/share/gnome-shell/extensions/${uuid}"
    unzip -qo "${uuid}.zip" -d "$HOME/.local/share/gnome-shell/extensions/${uuid}"
  }

  # Install these extensions
  install_extension "dash-to-dock@micxgx.gmail.com" "Dash to Dock"
  install_extension "blur-my-shell@aunetx" "Blur My Shell"
  install_extension "appindicatorsupport@rgcjonas.gmail.com" "AppIndicator Support"
  # TODO: add just-perfection

  
  # Enable them
  echo "✅ Enabling extensions..."
  gnome-extensions enable dash-to-dock@micxgx.gmail.com
  gnome-extensions enable blur-my-shell@aunetx
  gnome-extensions enable appindicatorsupport@rgcjonas.gmail.com

  echo "🎉 GNOME customization complete. You may need to log out and back in for some changes to fully apply."
}

# Call it if this is the main script
# setup_gnome_extras
