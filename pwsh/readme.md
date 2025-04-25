# Powershell Documentation

This section of the documentation includes all the PowerShell-specific documentation.

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

### Custom PowerShell Functions
1. **Install-Choco**: Installs Chocolatey if not already installed.
2. **Install-ChocoPackages**: Installs a list of Chocolatey packages from an array.
3. **Set-PSReadLineModule**: Configures the `PSReadLine` module for enhanced command-line experience.
4. **Install-KubeCLI**: Installs and configures `kubectl` and `kubelogin`.
5. **Shell Customizations**:
   - Configures `starship` prompt with a custom `starship.toml` file.
   - Includes settings for Azure, Git branches, and Git commits.
6. **numlock on by default**: 
7. **longpath support**: `Enable-LongPaths` allows support for longerfile paths.  
**TODO: expand with all functions**

### Additional Notes
- The scripts also include steps for debloating Windows using tools like `tiny11builder` and [`Win11Debloat`](https://github.com/Raphire/Win11Debloat/tree/master) .
- The `starship` prompt is customized with specific settings for Azure and Git workflows.
- The `PSReadLine` module is configured to enhance the PowerShell command-line experience with features like prediction view styles.

### Safely Activate every windows version

Below links feature save ways to activate any windows distro & onprem office

- [MassGrave](https://massgrave.dev/)
- [Official MAS Github Repo](https://github.com/massgravel/Microsoft-Activation-Scripts)