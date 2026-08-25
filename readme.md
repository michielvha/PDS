# Portable Deploy Suite

This repository contains all my deployment functions and documentation, supporting both **Windows** (`pwsh`), **linux** `bash` and **macOS** (`darwin`).

## Overview  

The goal of this project is to create a personal deployment repository that simplifies the configuration & installation of essential tooling on both Windows and Linux.

- **Supported Platforms:**  
  - Windows (PowerShell)  
  - Linux (Bash)  
    - **Distributions:** Fedora-based & Debian-based
  - MacOS (Darwin)

## Structure

This section provides references to the specific `readme.md` files in the respective architecture folders for detailed information about each architecture.

- **[Bash](bash/readme.md)**  
  - Includes modules for Fedora and Debian-based distributions.
  - Provides reusable scripts for system configuration and automation.

- **[PowerShell](pwsh/readme.md)**  
  - Contains modular functions for Windows deployment.
  - Includes instructions for creating, publishing, and using PowerShell modules.

- **[Darwin (macOS)](darwin/readme.md)**  
  - Planned support for macOS with specific tools and configurations.

# Features and Enhancements

## Current Features

- **Cross-Platform Support:**  
  - Windows (PowerShell)  
  - Linux (Bash)  

- **Modular Design:**  
  - Functions and scripts are organized into reusable modules.

- **Automation:**  
  - Scripts automate common deployment tasks, such as installing software and configuring environments.

## Planned Enhancements

### General
- [ ] Add proper testing and linting to pipelines.
- [ ] Improve error handling and logging across all scripts.

### Windows
- [ ] Pin frequently used applications to the taskbar.
- [ ] Wrap 'W11Debloat' to run on initial run of script
- [ ] Add functions for system diagnostics and machine information retrieval. (check old scripts for example)
- [ ] Enhance `Install-KubeCLI` to check for dependencies like Azure CLI.
- [ ] add custom logging / proper error handling to script. (check old scripts)
- [ ] function for aliasses Kubectl

check notes on phone for more idea's.

### Linux
- [x] Single bootstrap entrypoint binding the function library together (`bootstrap_workstation`).
- [ ] Extend the bootstrap beyond Debian/Ubuntu to Fedora and Arch.
- [x] Remove the dead duplicate function copies in `packaging/lib/` (never referenced by nfpm; wrappers ported to `bash/debian/software/hashicorp.sh`).
- [ ] Decide what to do with `bash/module/`, superseded by `bash/common/` but kept for now.
- [ ] Sync shell history across devices (consider creating a separate project in Go).
- [ ] Add support for Unifi server and sideload tools like AltStore.

# Bootstrapping a Linux workstation

Takes a fresh Debian/Ubuntu install to a working dev machine in one command: base packages, the dev
stack, GitHub auth, and every non-archived repo cloned into `~/code/personal`.

```bash
source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/debian/deploy/bootstrap.sh)
bootstrap_workstation
```

If the `pds` package is already installed, use the CLI instead:

```bash
pds bootstrap          # everything
pds bootstrap repos    # just clone anything missing
```

## Stages

Each stage is independently runnable (`bootstrap_workstation <stage>`) and safe to re-run.

| Stage | Does |
|---|---|
| `base` | `full_upgrade`, core CLI packages, passwordless sudo, bat, zsh + Zi + powerlevel10k |
| `stack` | docker, go, node, kubectl, azure cli, aws cli, vscode, claude code |
| `github` | GitHub CLI + Git Credential Manager, `gh auth login`, git identity + credential routing |
| `repos` | clones all non-archived repos for the configured owners |

## Configuration

Export any of these before running to override the defaults:

| Variable | Default |
|---|---|
| `PDS_WORKSPACE` | `~/code/personal` |
| `PDS_GIT_IDENTITY` | `michielvha` |
| `PDS_GIT_NAME` | `michielvha` |
| `PDS_GIT_EMAIL` | `michielvh@outlook.com` |
| `PDS_GITHUB_OWNERS` | `michielvha vhco-pro` |

## Git identity model

The `github` stage configures two independent mechanisms, which is what makes multiple GitHub accounts
coexist on one host:

- **Commit identity** is bound by directory. An `includeIf "gitdir:~/code/personal/"` entry in
  `~/.gitconfig` pulls in `~/.gitconfig.d/michielvha.inc`, so every commit made anywhere under the
  workspace is authored as `michielvha` regardless of the machine-wide default.
- **Credentials** are routed by remote URL, via `credential.https://github.com/<owner>.username`.
  This applies even to repos cloned outside the workspace, and more specific owner entries always win
  over the catch-all, so adding a work account later doesn't disturb this one.

Verify either with `show_git_identity` and `verify_github_credentials`.

Because `gh` keeps its tokens in its own keyring, which git never reads, `sync_github_credentials`
copies the live token into git's credential store. Re-run it if a `gh auth login`/`refresh` ever leaves
git authenticating as the wrong account.

# Getting Started

1. Clone the repository:
   ```bash
   git clone https://github.com/michielvha/PDS.git
   cd PDS
   ```

2. Follow the instructions in the respective `readme.md` files for Bash or PowerShell to set up your environment.

3. Run the scripts or modules as needed to deploy your personal setup.

# References

## Windows
- [PowerShell Gallery](https://www.powershellgallery.com/)   
- [Tiny11Builder](https://github.com/ntdevlabs/tiny11builder)  
- [Win11Debloat](https://github.com/Raphire/Win11Debloat/tree/master)
- [Crapfixer](https://github.com/builtbybel/Crapfixer): removes a lot of the bloatware and bad settings from Windows 11.