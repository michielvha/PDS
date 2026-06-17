#!/bin/bash
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/common/software/configure_ghostty.sh) `

# Function: configure_ghostty
# Description: Write a consistent Ghostty config to ~/.config/ghostty/config so
#              all workstations share the same look. Skips macOS on purpose —
#              there the config lives under ~/Library/Application Support and is
#              left untouched.
configure_ghostty() {
    # macOS keeps its own config under Application Support — leave it alone
    [[ "$(uname)" == "Darwin" ]] && { echo "ℹ️  macOS detected — leaving existing Ghostty config as-is."; return 0; }

    local cfg_dir="$HOME/.config/ghostty"
    mkdir -p "$cfg_dir"
    cat > "$cfg_dir/config" <<'EOF'
theme = GitHub Dark Default
background-opacity = 0.90
background-blur-radius = 20
EOF
    echo "✅ Ghostty config written to $cfg_dir/config"
}
