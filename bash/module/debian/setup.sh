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

  declare -A extensions=(
    ["dash-to-dock@micxgx.gmail.com"]=307
    ["blur-my-shell@aunetx"]=3193
    ["appindicatorsupport@rgcjonas.gmail.com"]=615
    ["clipboard-history@alexsaveau.dev"]=4839
    ["just-perfection-desktop@just-perfection"]=3843
    ["top-bar-organizer@julian.gse.jg@gmail.com"]=5172
  )

  GNOME_VERSION=$(gnome-shell --version | awk '{print $3}' | cut -d '.' -f1)

  tmp_dir=$(mktemp -d)
  cd "$tmp_dir" || exit 1

  for uuid in "${!extensions[@]}"; do
    ext_id=${extensions[$uuid]}
    echo "⬇️  Installing $uuid (ID: $ext_id)"

    ext_info=$(wget -qO- "https://extensions.gnome.org/extension-info/?pk=$ext_id")
    version_tag=$(echo "$ext_info" | jq -r --arg ver "$GNOME_VERSION" '.shell_version_map[$ver].pk')

    if [[ -z "$version_tag" || "$version_tag" == "null" ]]; then
      echo "⚠️  No compatible version found for GNOME Shell $GNOME_VERSION and $uuid"
      continue
    fi

    zip_file="${uuid}.zip"
    wget -q --show-progress -O "$zip_file" "https://extensions.gnome.org/download-extension/${uuid}.shell-extension.zip?version_tag=$version_tag"

    if [[ $? -ne 0 || ! -s "$zip_file" ]]; then
      echo "❌ Failed to download $uuid"
      continue
    fi

    install_dir="$HOME/.local/share/gnome-shell/extensions/$uuid"
    rm -rf "$install_dir"
    mkdir -p "$install_dir"
    unzip -qqo "$zip_file" -d "$install_dir"

    gnome-extensions enable "$uuid" && echo "✅ Installed and enabled $uuid"
  done

  rm -rf "$tmp_dir"
  echo "🎉 All extensions installed. Restart GNOME Shell (Alt+F2 → r or logout) to apply them."
  
  # verify
  # gsettings get org.gnome.shell enabled-extensions
}

install_juno_theme() {
  echo "🎨 Installing Juno GTK Theme..."

  # Variables
  THEME_URL="https://github.com/EliverLara/Juno/archive/refs/heads/master.zip"
  THEME_NAME="Juno"
  THEME_DIR="$HOME/.themes"

  # Create theme directory if it doesn't exist
  mkdir -p "$THEME_DIR"

  # Download and extract
  tmp_dir=$(mktemp -d)
  echo "⬇️  Downloading theme..."
 wget -q --show-progress -O "$tmp_dir/juno.zip" "$THEME_URL"

  echo "📦 Extracting theme to $THEME_DIR..."
  unzip -q "$tmp_dir/juno.zip" -d "$tmp_dir"
  mv "$tmp_dir/Juno-master" "$THEME_DIR/$THEME_NAME"

  # Set the theme via gsettings
  echo "⚙️  Setting Juno as the GTK and WM theme..."
  gsettings set org.gnome.desktop.interface gtk-theme "$THEME_NAME"
  gsettings set org.gnome.desktop.wm.preferences theme "$THEME_NAME"

  # Workaround to Apply Juno Theme to Libadwaita Apps
  mkdir -p ~/.config/gtk-4.0-backup
  cp -r ~/.config/gtk-4.0/* ~/.config/gtk-4.0-backup/ 2>/dev/null || true
  mkdir -p ~/.config/gtk-4.0
  cp -r ~/.themes/Juno/gtk-4.0/* ~/.config/gtk-4.0/


  echo "✅ Juno theme installed and applied!"
  echo "💡 You can also tweak more in GNOME Tweaks if needed."

  # Clean up
  rm -rf "$tmp_dir"
}

jetbrains_font() {
  echo "🔤 Installing JetBrains Mono font system-wide..."

  FONT_URL="https://download.jetbrains.com/fonts/JetBrainsMono-2.304.zip"
  FONT_DIR="/usr/local/share/fonts/JetBrainsMono"

  # Create temp directory
  tmp_dir=$(mktemp -d)
  echo "⬇️  Downloading JetBrains Mono font..."
  wget -q --show-progress -O "$tmp_dir/jetbrains-mono.zip" "$FONT_URL"

  echo "📦 Extracting to $FONT_DIR..."
  unzip -q "$tmp_dir/jetbrains-mono.zip" -d "$tmp_dir"

  # Ensure font directory exists
  sudo mkdir -p "$FONT_DIR"

  # Copy all .ttf files (skip docs or licenses)
  sudo cp -v "$tmp_dir/fonts/ttf/"*.ttf "$FONT_DIR/"

  # Clean up
  rm -rf "$tmp_dir"

  # Update font cache system-wide
  echo "🔄 Updating font cache..."
  sudo fc-cache -f -v
  echo "✅ JetBrains Mono font installed system-wide!"

}

# look into: SF Pro / SF UI / Inter for mac like fonts
set_gnome_fonts() {
  echo "🎨 Setting GNOME fonts and rendering..."

  gsettings set org.gnome.desktop.interface font-name 'JetBrains Mono 11'
  gsettings set org.gnome.desktop.interface document-font-name 'JetBrains Mono 11'
  gsettings set org.gnome.desktop.interface monospace-font-name 'JetBrains Mono 13'

  echo "✅ Font configuration applied."
}
