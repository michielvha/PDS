#!/bin/bash
# Debian-specific UI configuration functions
# This module contains functions for configuring the desktop environment, themes, and fonts on Debian systems

# Function: jetbrains_font
# Description: Installs the JetBrains Mono font system-wide
# Usage: jetbrains_font
# Arguments: none
# Returns:
#   0 - Success
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