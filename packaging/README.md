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

VHCO and Stackweaver banners convert the official
[VHCO](https://github.com/vhco-pro/.github/blob/main/profile/assets/vhco.png) and
[Stackweaver](https://github.com/vhco-pro/.github/blob/main/profile/assets/stackweaver.png)
logo silhouettes to plain ASCII above the FIGlet Big names. EdgeForge keeps its original artwork.
These are plain text assets with no formatter or image dependency at runtime.

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

The image-provisioning container is a disposable root test fixture. It needs Ubuntu, a package
manager and service binaries to exercise system configuration, so it uses a digest-pinned Ubuntu
base instead of an application runtime image. Source is mounted read-only and the tests run with
networking disabled. It is never a production runtime or a published container.

Run `bash tests/check-package.sh` from the repository root with Docker, Make, curl and ShellCheck
available on an amd64 Linux host. It verifies the pinned nFPM archive, builds a local candidate and
runs all package/helper checks in disposable Ubuntu. The existing PR/publisher workflow uses the
same verified compiler, strict lint target and package tests. PR jobs have read-only tokens and
version calculation never tags; the release job creates the tag at the checked commit after tests.
The local check does not tag, publish a package or deploy the APT repository. `make -C packaging lint-image-provisioning`
checks the relevant shell files without suppressing failures. The older broad lint target retains
its existing behavior for unrelated scripts.

## VirtIO driver ISO helpers

`install_virtio_win_iso` and `enable_virtio_win_iso_updates` keep the VirtIO driver ISO for Windows
guests current in a Proxmox VE or other ISO directory. The weekly job in `/etc/cron.d/pds-virtio-win`
sources the packaged library, so an APT upgrade of PDS also updates the refresh logic. See
[VirtIO drivers for Windows guests](../bash/debian/readme.md#virtio-drivers-for-windows-guests) for
the one-command setup and behavior.

## Update and SSH policy helpers

`update_system_cron_entry` selects the nightly midnight APT update/upgrade policy. Install cron
through the operating system first. The helper installs one managed job under `/etc/cron.d`, enables
cron on systemd hosts, and migrates only the exact legacy job it previously wrote to `/etc/crontab`.
It preserves other cron entries and keeps a backup before that migration. Start cron explicitly on
an ordinary host if it is not running; a newly booted image starts the enabled service normally.

The installed updater runs non-interactively, preserves modified conffiles with dpkg's default/old
handling, and bounds waits/retries for APT lists and dpkg locks to five minutes. Failures remain
nonzero and output goes to `/var/log/pds-update.log`. Ubuntu's existing APT timers remain enabled.
`PDS_UPDATE_LOCK_TIMEOUT` can reduce the lock budget for a manual run or a test; it accepts 1-300
seconds. No automatic reboot is configured. Re-run the helper to refresh its installed script after
updating PDS; the package does not overwrite generated host configuration automatically.

`restricted_ssh_security_profile` selects key-only, non-root SSH in a managed `00-pds-security.conf`
drop-in. It validates the existing and resulting OpenSSH configuration and checks the effective
settings. It restores the previous managed file if the selected settings do not take effect.
It never reloads the daemon. On an ordinary host, verify the intended non-root key access and then
explicitly reload the distribution's SSH service. An image recipe calls this helper after package
installers and leaves activation to the next boot. When a caller defines `pds_before_ssh_policy`,
the helper invokes that function before applying the policy; builders uses it to observe the running
SSH service without duplicating the policy implementation.

These helpers are explicit selections. A standalone installation or custom image recipe may omit
them or choose another policy. Omitting a call does not remove policy already configured on a host.

The installed library can also be sourced from Zsh with `source /usr/share/pds/init.sh`.
Loading definitions preserves the caller's options and performs no downloads. Local imports and
bundled assets resolve relative to their defining file in either shell. The image provisioning
example and `pds` CLI execute in Bash; this does not promise Zsh compatibility for every historical
helper's implementation.

## kubectl and Krew

`install_kubectl 1.37` installs kubectl from the selected Kubernetes minor APT channel and keeps
Krew in the invoking user's `$HOME/.krew`, or an explicit custom `KREW_ROOT`. An inherited
`/usr/local/share/pds/krew` selects the per-user default instead. The user's profile records the
selected root so later shells use it too. It adds the alias, completion and plugin
path to that user's Bash or Zsh configuration. Open a new shell after installation. The default
channel is 1.37; choose the channel appropriate for your cluster's supported client version skew.

For reusable images, call `install_kubectl 1.37 --system` from root Bash. This explicitly selects
`/usr/local/share/pds/krew`, owned by root and readable/executable by new users. Bash and Zsh load
its path and alias through shared configuration; Bash completion is installed system-wide and the
existing PDS Zsh configuration enables kubectl completion. Zi's shell-plugin downloads are unchanged.
Use `install_kubectl` for current kubectl installations. The older `configure_kubectl_plugins`
helper is outside this image integration and still contains a legacy Zsh alias-completion mapping;
its compatibility with current kubectl is not established by these checks.
Users can set a private `KREW_ROOT` before loading the shell configuration for their own plugins;
updating the shared installation requires an administrator.

Image mode requires the package or a complete checkout. The ordinary raw workstation bootstrap
fetches the checksum data at the explicit installation call, using its `PDS_REF` (default `main`).
`bash/config/krew-releases.sha256` records the exact Krew release archive and SHA-256 for amd64 and
arm64. The installer verifies the archive
before executing it and bootstraps Krew from that same archive. Krew then verifies its index's
manifests for neat, view-secret and stern. All three are required; download or plugin failures stop
the selected installation. The plugin index is resolved at installation time, so these plugin
versions can change between builds. Image validation records their installed versions.
