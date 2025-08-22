#!/bin/bash
# PDS Pre-removal script
set -e

echo "Removing PDS (Personal Development Scripts)..."

# Clean up any temporary files or caches if they exist
if [ -d "/tmp/pds-cache" ]; then
    rm -rf /tmp/pds-cache
    echo "Cleaned up temporary files"
fi

# Note: The package manager will automatically remove:
# - /usr/share/pds-funcs/
# - /etc/profile.d/pds-funcs.sh  
# - /usr/bin/pds

echo "PDS functions will be removed from new shells."
echo "Current shell sessions will retain loaded functions until closed."
echo "Thank you for using PDS!"
