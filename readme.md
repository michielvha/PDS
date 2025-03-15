# Personal Deploy Script

This repository contains all my deployment functions, supporting both PowerShell (`pwsh`) and Bash. macOS (`darwin`) support is planned for a future update.

## Overview  

The goal of this project is to create a personal deployment repository that simplifies the configuration & installation of essential tooling on both Windows and Linux.

- **Supported Platforms:**  
  - Windows (PowerShell)  
  - Linux (Bash)  
    - **Distributions:** Fedora-based & Debian-based

[//]: # (I'll be wanting to use package managers or either wget to fetch the urls)

## Future enhancements

### Windows 

- [ ] add proper testing / linting to the pipelines
- [ ] Pin items to the task bar
- [ ] add custom logging / proper error handling to script
- [ ] function for aliasses Kubectl
- [ ] function to run system diagnostic
- [ ] function to fetch relevant information about machine (check old scripts for example)
- [ ] Modify `Install-KubeCLI` to check if az cli is install before using it to install ``kubectl`` & ``kubelogin``

check notes on phone for more idea's.

## windows specific

**Step 1: debloat windows by using this [script](https://github.com/Raphire/Win11Debloat/tree/master) define which options and settings you want to set or use tiny11 on standard image to create custom trimmed image.**

binaries installed in sys directory and added to path => handeld if installed via choco

- [x] grep on windows
- [x] cat on windows, via unxutils

shell config
- [x] starship + ps readline config


various tweaks in registry

- numlock on by default
- [x] long path support in registry
<!-- - backlit keyboard on by default if available => seems to be controlled by bios -->

## Linux Specific ( check edgecloud for more ideas)

configure zsh
set locale

### future enhancements:

- sync shell history across all devices => Create a seperate project in Go for this.
- unifi server local host?
- atlstore or other sideload tool localhost

### Script Docs
### Pipeline Docs


to add:
````shell
bginfo / neofetch
gh cli
docker
Firefox (with extensions)
````
