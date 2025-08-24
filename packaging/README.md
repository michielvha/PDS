# PDS APT Package

This directory contains the packaging configuration to build PDS (Portable Deploy Suite) as a proper Debian/Ubuntu APT package.

## Overview

The PDS package provides a comprehensive collection of Bash functions for:

- **Software Installation**: Docker, VS Code, kubectl, HashiCorp tools, and more
- **UI/Theme Setup**: Fonts, GTK themes, GNOME configuration
- **Development Environment**: Git, Azure CLI, development tools
- **System Deployment**: Post-deployment scripts and configuration

## Features

✅ **Auto-loading**: Functions are automatically available in new interactive shells  
✅ **Versioned**: Proper semantic versioning with APT upgrade support  
✅ **Signed**: GPG-signed packages for security  
✅ **CLI Helper**: `pds` command for discovery and management  
✅ **Opt-out**: Users can disable with `export PDS_DISABLE=1`  

## Quick Start

### Building the Package

```bash
# Install nfpm (if not already installed)
# See: https://nfpm.goreleaser.com/install/

# Build the package
cd packaging/
make build

# Install locally for testing
make install

# Test the installation
pds doctor
pds list
```

### Using PDS Functions

Once installed, functions are automatically available:

```bash
# Open a new shell and use functions directly
install_docker        # Install Docker
install_vscode        # Install VS Code
install_packer        # Install HashiCorp Packer
install_jetbrains_font # Install JetBrains Mono font

# Use the CLI helper
pds help              # Show help
pds list              # List all functions
pds search docker     # Find Docker-related functions
pds show install_docker # Show function source code
```

## Package Structure

```
/usr/share/pds-funcs/           # Main library directory
├── software/                   # Software installation functions
│   ├── install_docker.sh      # Docker installation
│   ├── install_vscode.sh      # VS Code installation
│   ├── hashicorp.sh           # HashiCorp tools
│   └── ...
├── ui/                        # UI/Theme functions
│   ├── install_jetbrains_font.sh
│   ├── install_tokyonight_theme.sh
│   └── ...
├── deploy/                    # Deployment functions
│   └── postdeployment.sh
└── init.sh                    # Main initialization script

/etc/profile.d/pds-funcs.sh    # Auto-loader for interactive shells
/usr/bin/pds                   # CLI helper tool
```

## Development

### Prerequisites

- `nfpm` for package building
- `make` for build automation
- `shellcheck` for linting (optional)
- `docker` for testing (optional)

### Available Make Targets

```bash
make help       # Show available targets
make build      # Build the .deb package
make install    # Install locally (requires sudo)
make uninstall  # Remove the package
make test       # Test in Docker container
make lint       # Run shellcheck on scripts
make validate   # Validate package configuration
make clean      # Clean build artifacts
make info       # Show package information
```

### Adding New Functions

1. Add your `.sh` file to the appropriate directory in `../bash/debian/`
2. Follow the existing naming convention
3. Test your functions
4. Update version in `nfpm.yaml` and `Makefile`
5. Rebuild the package

### Package Configuration

The package is configured in `nfpm.yaml`:

- **Source**: Uses existing `../bash/debian/` structure
- **Target**: Installs to `/usr/share/pds-funcs/`
- **Auto-loading**: Via `/etc/profile.d/pds-funcs.sh`
- **Dependencies**: bash, curl, wget, gpg

## Distribution

### Setting Up Your Own APT Repository

1. **Using aptly** (recommended for self-hosting):

```bash
# Install aptly
apt install aptly

# Create repository
aptly repo create pds-repo
aptly repo add pds-repo dist/pds-funcs_1.0.0_all.deb

# Publish repository
aptly publish repo -distribution=stable -architectures=all pds-repo

# Upload to your static host (S3, GitHub Pages, etc.)
```

2. **Using hosted services**:
   - [Cloudsmith](https://cloudsmith.io/)
   - [PackageCloud](https://packagecloud.io/)
   - [GitHub Packages](https://github.com/features/packages)

### Client Installation

```bash
# Add your repository
curl -fsSL https://your-host/pds-repo.gpg | sudo tee /usr/share/keyrings/pds-repo.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/pds-repo.gpg] https://your-host/ stable main" | \
  sudo tee /etc/apt/sources.list.d/pds-repo.list

# Install PDS
sudo apt update
sudo apt install pds-funcs
```

## Function Categories

### Software Installation (`software/`)
- `install_docker.sh` - Docker and Docker Compose
- `install_vscode.sh` - Visual Studio Code
- `install_kubectl.sh` - Kubernetes CLI
- `hashicorp.sh` - Packer, Terraform, Vault, Consul
- `install_azcli.sh` - Azure CLI
- `python.sh` - Python development tools
- And many more...

### UI/Theme Setup (`ui/`)
- `install_jetbrains_font.sh` - JetBrains Mono font
- `install_tokyonight_theme.sh` - Tokyo Night GTK theme
- `install_juno_theme.sh` - Juno GTK theme
- `set_gnome_fonts.sh` - GNOME font configuration
- `setup_gnome_extras.sh` - GNOME shell extensions

### Deployment (`deploy/`)
- `postdeployment.sh` - Post-deployment configuration scripts

## Troubleshooting

### Common Issues

1. **Functions not loading**:
   ```bash
   pds doctor                    # Check installation health
   source /usr/share/pds-funcs/init.sh  # Manual load
   ```

2. **Permission issues**:
   ```bash
   ls -la /usr/share/pds-funcs/  # Check file permissions
   sudo chown -R root:root /usr/share/pds-funcs/
   ```

3. **Disable auto-loading**:
   ```bash
   export PDS_DISABLE=1          # Temporary disable
   # Add to ~/.bashrc for permanent disable
   ```

### Getting Help

- Run `pds help` for CLI usage
- Run `pds doctor` to check installation
- Check `/var/log/dpkg.log` for installation issues
- Visit [GitHub Issues](https://github.com/michielvha/PDS/issues)
