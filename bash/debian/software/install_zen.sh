#!/bin/bash
# Function: install_zen
# Description: Installs Zen Browser
# Source: `source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/debian/software/install_vscode.sh)`

install_zen() {
  echo "🌐 Installing Zen Browser..."

  # Ensure required packages are present
  sudo apt update
  sudo apt install -y wget bzip2 xz-utils jq

  # Define install paths
  INSTALL_DIR="/opt"
  BIN_LINK="/usr/bin/zen"
  DESKTOP_FILE="/usr/local/share/applications/zen.desktop"

  sudo mkdir -p /usr/local/share/applications/

  echo "🔎 Resolving latest release tag..."
  TAG=$(curl -sL -o /dev/null -w "%{url_effective}" https://github.com/zen-browser/desktop/releases/latest | grep -oP 'tag/\K[^/]+')

  if [[ -z "$TAG" ]]; then
    echo "❌ Failed to resolve latest release tag."
    return 1
  fi

  echo "📌 Latest tag found: $TAG"

  ARCH=$(uname -m)
  case "$ARCH" in
    x86_64)
      PATTERN='zen\.linux\-x86_64\.tar\.(xz|bz2)$'
      ;;
    aarch64|arm64)
      PATTERN='zen\.linux\-aarch64\.tar\.(xz|bz2)$'
      ;;
    *)
      echo "❌ Unsupported architecture: $ARCH"
      return 1
      ;;
  esac

  echo "🌐 Fetching release data from GitHub API..."
  RELEASE_JSON=$(curl -s "https://api.github.com/repos/zen-browser/desktop/releases/tags/$TAG")

  DOWNLOAD_URL=$(echo "$RELEASE_JSON" | jq -r --arg pattern "$PATTERN" '.assets[] | select(.name | test($pattern)) | .browser_download_url')

  if [[ -z "$DOWNLOAD_URL" ]]; then
    echo "❌ Failed to find a Zen release matching your architecture."
    return 1
  fi

  ARCHIVE_EXT="${DOWNLOAD_URL##*.}"
  echo "⬇️ Downloading Zen Browser from $DOWNLOAD_URL..."
  tmp_dir=$(mktemp -d)
  archive="$tmp_dir/zen.tar.$ARCHIVE_EXT"

  wget -qO "$archive" "$DOWNLOAD_URL" || {
    echo "❌ Download failed."
    return 1
  }

  echo "📦 Extracting..."
  sudo mkdir -p "$INSTALL_DIR"
  if [[ "$ARCHIVE_EXT" == "xz" ]]; then
    sudo tar -xJf "$archive" -C "$INSTALL_DIR"
  else
    sudo tar -xjf "$archive" -C "$INSTALL_DIR"
  fi

  echo "🔗 Creating symlink to /usr/bin/zen..."
  sudo ln -sf "$INSTALL_DIR/zen/zen" "$BIN_LINK"

  echo "🖥️ Creating desktop entry..."
  sudo tee "$DESKTOP_FILE" > /dev/null <<EOF
[Desktop Entry]
Version=1.0
Name=Zen Browser
Comment=Experience tranquillity while browsing the web without people tracking you!
GenericName=Web Browser
Keywords=Internet;WWW;Browser;Web;Explorer
Exec=zen
Terminal=false
X-MultipleArgs=false
Type=Application
Icon=/opt/zen/browser/chrome/icons/default/default128.png
Categories=GNOME;GTK;Network;WebBrowser;
MimeType=text/html;text/xml;application/xhtml+xml;application/xml;application/rss+xml;application/rdf+xml;image/gif;image/jpeg;image/png;x-scheme-handler/http;x-scheme-handler/https;x-scheme-handler/ftp;x-scheme-handler/chrome;video/webm;application/x-xpinstall;
StartupNotify=true
EOF

  echo "✅ Zen Browser installed! You can now find it in your application launcher."
}
