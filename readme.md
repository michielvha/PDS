# Personal Deploy Script

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

## Future enhancements

### Windows 

- [ ] add proper testing / linting to the pipelines
- [ ] Pin items to the task bar
- [ ] add custom logging / proper error handling to script
- [ ] function for aliasses Kubectl
- [ ] function to run system diagnostic
- [ ] function to fetch relevant information about machine (check old scripts for example)
- [ ] Modify `Install-KubeCLI-Azure` to check if az cli is install before using it to install ``kubectl`` & ``kubelogin``

check notes on phone for more idea's.

## Linux Specific ( check edgecloud for more ideas)

configure zsh
set locale

### future enhancements:

- sync shell history across all devices => Create a seperate project in Go for this.
- unifi server local host?
- atlstore or other sideload tool localhost




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
- [ ] Add functions for system diagnostics and machine information retrieval.
- [ ] Enhance `Install-KubeCLI` to check for dependencies like Azure CLI.

### Linux
- [ ] Sync shell history across devices (consider creating a separate project in Go).
- [ ] Add support for Unifi server and sideload tools like AltStore.

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