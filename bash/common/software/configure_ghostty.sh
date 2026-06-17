#!/bin/bash
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/common/software/configure_ghostty.sh) `

# Function: configure_ghostty
# Description: Write a consistent Ghostty config to ~/.config/ghostty/config.
#              Works on both Linux and macOS (Ghostty reads this XDG path on both).
configure_ghostty() {
    local cfg_dir="$HOME/.config/ghostty"
    mkdir -p "$cfg_dir"
    cat > "$cfg_dir/config" <<'EOF'
theme = GitHub Dark Default
background-opacity = 0.90
background-blur-radius = 20
EOF
    echo "✅ Ghostty config written to $cfg_dir/config"
}
