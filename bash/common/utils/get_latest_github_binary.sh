#!/bin/bash
# Function: get_latest_github_binary
# Description: Downloads and installs the latest release of a binary from a specified GitHub repository.
# Usage: get_latest_github_binary
# Arguments: none
# Returns:
#   0 - Success
#   1 - Failure (e.g., unsupported architecture, missing binary, or download issues)

# Get a binary from github
get_latest_github_binary() {
  local repo="michielvha/edgectl"
  local binary_name="edgectl"
  local install_path="/usr/local/bin"

  echo "🔍 Fetching latest release info for $repo..."

  # Detect OS and Arch
  os=$(uname | tr '[:upper:]' '[:lower:]')
  arch=$(uname -m)
  case $arch in
    x86_64) arch="amd64" ;;
    aarch64 | arm64) arch="arm64" ;;
    *) echo "❌ Unsupported architecture: $arch"; return 1 ;;
  esac

  # Get latest release tag
  latest_url=$(curl -sL "https://api.github.com/repos/$repo/releases/latest" | \
    grep "browser_download_url" | \
    grep "$os.*$arch" | \
    grep "$binary_name" | \
    cut -d '"' -f 4)

  if [[ -z "$latest_url" ]]; then
    echo "❌ Could not find a release asset for $os/$arch"
    return 1
  fi

  echo "⬇️ Downloading: $latest_url"
  tmp_dir=$(mktemp -d)
  cd "$tmp_dir" || return 1

  curl -LO "$latest_url"

  archive=$(basename "$latest_url")

  # Extract based on file type
  if [[ $archive == *.tar.gz ]]; then
    tar -xzf "$archive"
  elif [[ $archive == *.zip ]]; then
    unzip "$archive"
  fi

  if [[ -f "$binary_name" ]]; then
    chmod +x "$binary_name"
    sudo mv "$binary_name" "$install_path/"
    echo "✅ Installed $binary_name to $install_path"
  else
    echo "❌ Binary not found in the archive."
    return 1
  fi

  # Cleanup
  cd /
  rm -rf "$tmp_dir"
}