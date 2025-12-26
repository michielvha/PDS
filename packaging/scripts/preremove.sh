#!/bin/bash
# PDS Pre-removal script
set -e

echo "Removing PDS (Personal Development Scripts)..."

# Remove PDS auto-loading from /etc/zsh/zshrc
if [ -f /etc/zsh/zshrc ]; then
    if grep -q "# PDS auto-loading" /etc/zsh/zshrc 2>/dev/null; then
        # Remove the PDS section (from marker to end marker, including blank line before if present)
        sed -i '/# PDS auto-loading/,/# End of PDS auto-loading/d' /etc/zsh/zshrc
        echo "✅ Removed PDS auto-loading from /etc/zsh/zshrc"
    fi
fi

# Remove PDS auto-loading from /etc/bash.bashrc
if [ -f /etc/bash.bashrc ]; then
    if grep -q "# PDS auto-loading" /etc/bash.bashrc 2>/dev/null; then
        # Remove the PDS section (from marker to end marker, including blank line before if present)
        sed -i '/# PDS auto-loading/,/# End of PDS auto-loading/d' /etc/bash.bashrc
        echo "✅ Removed PDS auto-loading from /etc/bash.bashrc"
    fi
fi

# Clean up any temporary files or caches if they exist
if [ -d "/tmp/pds-cache" ]; then
    rm -rf /tmp/pds-cache
    echo "✅ Cleaned up temporary files"
fi

# Note: The package manager will automatically remove:
# - /usr/share/pds/
# - /etc/profile.d/pds.sh  
# - /usr/bin/pds

echo "✅ PDS functions will be removed from new shells."
echo "ℹ️  Current shell sessions will retain loaded functions until closed."
echo "Thank you for using PDS!"
