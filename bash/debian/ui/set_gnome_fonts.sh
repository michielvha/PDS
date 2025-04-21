#!/bin/bash
# Debian-specific UI configuration functions
# This module contains functions for configuring the desktop environment, themes, and fonts on Debian systems

# Function: set_gnome_fonts
# Description: Configures GNOME fonts and rendering settings
# Usage: set_gnome_fonts
# Arguments: none
# Returns:
#   0 - Success
set_gnome_fonts() {
  echo "🎨 Setting GNOME fonts and rendering..."

  gsettings set org.gnome.desktop.interface font-name 'JetBrains Mono 11'
  gsettings set org.gnome.desktop.interface document-font-name 'JetBrains Mono 11'
  gsettings set org.gnome.desktop.interface monospace-font-name 'JetBrains Mono 13'

  echo "✅ Font configuration applied."
}