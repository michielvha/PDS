# Powershell Documentation

This section of the documentation includes all the PowerShell-specific documentation.

## Getting started

```pwsh
install-module PDS
import-module PDS
```

## Checks and releases

Every push of a branch that changes `pwsh/`, the analyzer settings, the workflows or `scripts/` runs the PowerShell checks on Windows with [pwsh-ci-action](https://github.com/vhco-pro/pwsh-ci-action): formatting and PSScriptAnalyzer against `PSScriptAnalyzerSettings.psd1` at the repository root, a module import in a fresh process, and the Pester tests in `pwsh/tests/`, one file per exported function. A failure blocks the version.

After the checks pass on `main`, a version-bumping commit (`feat:`, `fix:` and the other bumping types) gets an exact tag such as `v0.26.0`. That tag runs every check again, then publishes the module to the PowerShell Gallery, the Debian package to the APT repository, and a GitHub Release with notes, the `.deb` and `PDS-<version>.exe`. The module and package versions have no `v` prefix. Commits typed `docs`, `style`, `test` or `ci` release nothing.

## Windows software packages included

Below is a list of software and tools supported by the custom PowerShell functions and installed via Chocolatey:

### Software Installed via Chocolatey
- `nmap`
- `git`
- `azure-cli`
- `terraform`
- `pycharm-community`
- `angryip`
- `unxutils`
- `mobaxterm`
- `starship`
- `rpi-imager`
- `openlens` (or `lens`)
- `grep`
- `bginfo`
- `gh` (GitHub CLI)
- `docker`
- `Firefox`
- `awscli`

### Software installed via scoop

- `base64`

### Custom PowerShell Functions
1. **Install-Choco**: Installs Chocolatey if not already installed.
2. **Install-ChocoPackage**: Installs a list of Chocolatey packages from an array.
3. **Set-PSReadLineModule**: Configures the `PSReadLine` module for enhanced command-line experience.
4. **Install-AzureKubeCLI**: Installs and configures `kubectl` and `kubelogin`.
5. **Shell Customizations**:
   - Configures `starship` prompt with a custom `starship.toml` file.
   - Includes settings for Azure, Git branches, and Git commits.
6. **numlock on by default**: 
7. **longpath support**: `Enable-LongPath` allows support for longerfile paths.  
8. **SSH server**: `Enable-SshServer` installs/enables OpenSSH server, opens the firewall and optionally authorizes public keys.  
9. **WinRM server**: `Enable-WinRmServer` enables WinRM over HTTP with NTLM authentication, opens TCP 5985 on every network profile and optionally creates a local user for Ansible or other WinRM clients. `Disable-WinRmServer` reverses it.  
**TODO: expand with all functions**

### Additional Notes
- The scripts also include steps for debloating Windows using tools like `tiny11builder` and [`Win11Debloat`](https://github.com/Raphire/Win11Debloat/tree/master) .
- The `starship` prompt is customized with specific settings for Azure and Git workflows.
- The `PSReadLine` module is configured to enhance the PowerShell command-line experience with features like prediction view styles.

### Safely Activate every windows version

Below links feature save ways to activate any windows distro & onprem office

- [MassGrave](https://massgrave.dev/)
- [Official MAS Github Repo](https://github.com/massgravel/Microsoft-Activation-Scripts)
