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
/usr/share/pds/
├── common/                   # Shared libraries, grouped by category
├── debian/                   # Debian/Ubuntu libraries, grouped by category
├── config/                   # Zi configuration and the Powerlevel10k preset
├── init.sh                   # Explicit Bash entry point
└── VERSION

/etc/profile.d/pds.sh         # Interactive shell auto-loader
/usr/bin/pds                  # CLI helper
```

## Image provisioning with Zi

The shell setup uses Zi and the existing PDS Powerlevel10k preset.
Zi also loads the existing `OMZP::` snippets; it does not install or switch to the Oh My Zsh framework.
The preset under `bash/config/.p10k.zsh` is included in the package unchanged.

Use the complete [image provisioning example](../examples/image-provisioning/provision.sh) after configuring the PDS APT repository and installing Git and Zsh through the image's base package list.
Set `PDS_VERSION` to an exact published package version containing these helpers.
The example installs that version and explicitly sources `/usr/share/pds/init.sh` in Bash before applying the selected configuration.
Loading the package defines functions and reads local libraries; installation work starts only when a function is called.
A library that cannot be loaded makes initialization fail visibly.

`install_zi` reuses an existing installation and requires Git to be installed already.
It refuses to overwrite an existing directory that does not contain `zi.zsh`.
`configure_zsh` installs the shared configuration in `/etc/zshrc` and supplies the preset and loader for the current user and `/etc/skel`.
An existing configuration that differs is saved once with a `.pds-backup` suffix before replacement.
The standalone workstation bootstrap fetches missing shell assets only when `configure_zsh` is called, using `PDS_REF`; installed packages and complete checkouts use their local assets.
The function does not change the user's login shell; select that through clone-time user configuration, or call `set_default_zsh` explicitly on a workstation.

The Debian/Ubuntu helper `setup_motd [banner-file] [none|fastfetch|neofetch]` manages `/etc/update-motd.d/90-pds` and its optional banner under `/etc/pds`.
It leaves distribution and administrator MOTD scripts in place.
Without a banner it displays the current kernel; the default information-tool choice is `none`.
To use a system-information tool, install it separately and pass its name.
`PDS_MOTD_BANNER` and `PDS_MOTD_INFO` select those arguments in the example.

Choose a bundled text banner with `setup_motd_preset <name> [none|fastfetch|neofetch]`:

```bash
setup_motd_preset vhco
setup_motd_preset stackweaver
setup_motd_preset edgeforge
```

VHCO and Stackweaver have their own banner files. EdgeForge preserves the earlier plain banner;
its duplicate coloured copy is omitted. System information remains the helper's optional second
argument. Presets live under `bash/config/motd/` in a checkout and `/usr/share/pds/config/motd/`
in the package. Add a lowercase `.txt` file there for another preset; no duplicate function is needed.
Names may contain letters, digits, underscores and hyphens. Invalid names or missing files fail
before changing the active banner. `setup_motd /path/to/banner.txt` remains available for a custom file.
Banner files are printed as data and are never sourced as shell code.

Keep hostname, per-machine addresses and SSH keys in clone-time cloud-init.
Image sealing remains the builder's responsibility.
SSH hardening and automatic updates are explicit role choices; the example does not apply them during image creation.

Use the installed package or a complete checkout for the supported provisioning path.
The affected libraries prefer local helper files.
Their existing raw-URL fallback remains available for standalone use when a helper has not already been loaded.
Loading the complete installed package uses its local helpers and performs no downloads.
The workstation bootstrap explicitly loads those dependencies before calling installers.
The old administration and Azure import paths are compatibility shims to their maintained implementations.

Run `make -C packaging test-image-provisioning` to build and install the actual Debian package in disposable Ubuntu, then check strict offline loading, the preserved Zi configuration, preset delivery to a new user, MOTD repeatability and validated sudoers.
The offline Zi test records plugin requests instead of downloading plugin repositories.
It does not certify every installer, Fedora packaging or a complete Proxmox image build.

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
make test-image-provisioning # Test the built package, Zi, MOTD and strict loading
make lint       # Run shellcheck on scripts
make validate   # Validate package configuration
make clean      # Clean build artifacts
make info       # Show package information
```

### Adding New Functions

1. Add your `.sh` file to the appropriate category in `../bash/common/` or `../bash/debian/`.
2. Follow the existing naming convention
3. Test your functions
4. Update version in `nfpm.yaml` and `Makefile`
5. Rebuild the package

### Package Configuration

The package is configured in `nfpm.yaml`:

- **Source**: Includes `../bash/common/`, `../bash/debian/` and `../bash/config/`.
- **Target**: Installs to `/usr/share/pds/`
- **Auto-loading**: Via `/etc/profile.d/pds.sh`
- **Dependencies**: bash, curl, wget, gpg

## Distribution

### APT Repository (Recommended)

PDS is available via an APT repository hosted on GitHub Pages. This is the easiest way to install and keep PDS updated:

```bash
# Add GPG key
curl -fsSL https://michielvha.github.io/PDS/pds-repo.gpg | \
  sudo tee /usr/share/keyrings/pds-repo.gpg >/dev/null

# Add repository
echo "deb [signed-by=/usr/share/keyrings/pds-repo.gpg] https://michielvha.github.io/PDS/apt/ stable main" | \
  sudo tee /etc/apt/sources.list.d/pds-repo.list

# Update and install
sudo apt update
sudo apt install pds
```

The repository is automatically updated with each new release, maintaining all package versions for easy installation and upgrades.

### Direct Installation from GitHub Releases

You can also download and install the `.deb` file directly from [GitHub Releases](https://github.com/michielvha/PDS/releases):

```bash
# Download latest release
wget https://github.com/michielvha/PDS/releases/download/v1.0.0/pds_1.0.0_all.deb

# Install
sudo dpkg -i pds_1.0.0_all.deb
sudo apt-get install -f
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
   source /usr/share/pds/init.sh  # Manual load
   ```

2. **Permission issues**:
   ```bash
   ls -la /usr/share/pds/  # Check file permissions
   sudo chown -R root:root /usr/share/pds/
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
