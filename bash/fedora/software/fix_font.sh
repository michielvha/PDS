#!/bin/bash
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/fedora/software/fix_font.sh) `

#!/bin/bash

# Function: fix_font
# Description: Fixes font rendering in Fedora
fix_font() {
	echo "🔤 Fixing font rendering in Fedora..."

	echo "=== Fedora Font Rendering Fix Script ==="
    echo ""

    # Enable RPM Fusion if not already enabled
    echo "[1/4] Checking RPM Fusion repositories..."
    if ! dnf repolist | grep -q "rpmfusion-free"; then
        echo "Enabling RPM Fusion Free repository..."
        sudo dnf install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
    else
        echo "RPM Fusion already enabled."
    fi

    echo ""

    # Create fontconfig directory
    echo "[2/4] Setting up fontconfig..."
    mkdir -p ~/.config/fontconfig

    # Create proper fontconfig with full hinting
    cat > ~/.config/fontconfig/fonts.conf << 'EOF'
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
    <fontconfig>
    <match target="font">
        <edit name="antialias" mode="assign">
        <bool>true</bool>
        </edit>
        <edit name="hinting" mode="assign">
        <bool>true</bool>
        </edit>
        <edit name="hintstyle" mode="assign">
        <const>hintfull</const>
        </edit>
        <edit name="rgba" mode="assign">
        <const>rgb</const>
        </edit>
        <edit name="lcdfilter" mode="assign">
        <const>lcddefault</const>
        </edit>
    </match>
    </fontconfig>
    EOF

    echo "Created ~/.config/fontconfig/fonts.conf"
    echo ""

    # Rebuild font cache
    echo "[3/4] Rebuilding font cache..."
    fc-cache -fv

    echo ""
    echo "[4/4] Verifying settings..."
    echo ""
    echo "Current font rendering settings:"
    fc-match -v sans | grep -E "hintstyle|rgba|lcdfilter|antialias"

    echo ""
    echo "=== Done! ==="
    echo ""
    echo "Expected values:"
    echo "  antialias: True"
    echo "  hintstyle: 3 (hintfull)"
    echo "  rgba: 1 (RGB)"
    echo "  lcdfilter: 1 (lcddefault)"
    echo ""
    echo "IMPORTANT: Log out and log back in for changes to fully take effect!"
    echo "Wayland caches font rendering settings at session start."

}