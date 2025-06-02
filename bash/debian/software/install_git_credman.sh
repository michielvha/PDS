#!/bin/bash
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/debian/software/install_git_credman.sh) `

# Function: install_git_cm
# Description: Downloads and installs the git-credential-manager (GCM) for Linux with proper setup for headless/TTY environments using GPG encryption.
install_git_credman() {
    # Install dependencies
    sudo apt update
    sudo apt install -y gnupg pass

    # Download and install Git Credential Manager
    echo "Downloading latest Git Credential Manager..."
    
    # Get the tag name from the GitHub API
    latest_tag=$(curl -sL https://api.github.com/repositories/158405551/releases/latest | grep -o '"tag_name": "v[0-9.]*"' | cut -d'"' -f4)
    
    if [ -n "$latest_tag" ]; then
        # Remove 'v' prefix to get the version number
        echo "Latest version found: $latest_tag"
        version=${latest_tag#v}
        
        # Construct download URL
        download_url="https://github.com/GitCredentialManager/git-credential-manager/releases/download/${latest_tag}/gcm-linux_amd64.${version}.deb"
    else
        # Fallback to a known version if API call fails
        echo "Couldn't get latest version, using fallback version 2.6.1"
        download_url="https://github.com/GitCredentialManager/git-credential-manager/releases/download/v2.6.1/gcm-linux_amd64.2.6.1.deb"
    fi
    
    echo "Downloading from: $download_url"
    wget "$download_url" -O gcm-linux_amd64.deb
    sudo dpkg -i gcm-linux_amd64.deb
    
    # Configure Git to use GCM
    git config --global credential.helper manager
    
    # Configure GCM to use GPG/pass for credential storage
    git config --global credential.credentialStore gpg
    
    # Setup for headless/TTY environments
    echo "export GPG_TTY=$(tty)" >> ~/.bashrc
    
    # Add to current session
    GPG_TTY=$(tty)
    export GPG_TTY
    
    # Cleanup
    rm gcm-linux_amd64.deb
    
    echo ""
    echo "Git Credential Manager installed with GPG credential store"
    echo "-----------------------------------------------------------"
    
    # Check if GPG key exists
    if ! gpg --list-secret-keys | grep -q "sec"; then
        echo "No GPG key found. Creating a new GPG key..."
        
        # Create batch file for non-interactive GPG key generation
        cat > /tmp/gpg-batch << 'EOF'
%echo Generating a GPG key
Key-Type: RSA
Key-Length: 3072
Subkey-Type: RSA
Subkey-Length: 3072
Name-Real: Git Credential Manager
Name-Email: gcm@localhost
Expire-Date: 0
%no-protection
%commit
%echo Done
EOF
        
        # Generate the key
        gpg --batch --generate-key /tmp/gpg-batch
        rm /tmp/gpg-batch
        
        echo "GPG key generated successfully!"
    else
        echo "Existing GPG key found."
    fi
    
    # Get the key ID of the first available key
    GPG_KEY_ID=$(gpg --list-secret-keys --keyid-format LONG | grep -m 1 "sec" | sed -r 's/.*\/([A-Z0-9]+) .*/\1/')
    
    # Check if pass is initialized
    if ! pass ls > /dev/null 2>&1; then
        echo "Initializing pass with GPG key: $GPG_KEY_ID"
        pass init "$GPG_KEY_ID"
    else
        echo "Pass store already initialized"
    fi
    
    echo ""
    echo "Setup complete! The system is now configured to use GPG for secure credential storage."
    echo ""
    echo "For SSH sessions, ensure SSH_TTY is set correctly"
    echo "or add 'export GPG_TTY=\$(tty)' to your shell profile"
    echo ""
}