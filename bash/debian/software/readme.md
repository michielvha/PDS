# Debian-specific system configuration functions

This module contains functions for configuring the Debian system & installing additional software

## use

## index

TODO: Auto generate with links

## Debian Functions

| Function | Description |
|---|---|
| install_zen | Installs Zen Browser |
| install_librewolf | Installs librewolf browser |
| install_kubectl | Installs and configures kubectl |
| install_nvidia_ctk | Installs Nvidia container toolkit for container GPU support |
| install_lens | Installs and configures lens (Kubernetes IDE) on a Debian-based system. |
| install_freelens | Installs FreeLens (Open-source alternative to Lens) on a Debian-based system. |
| install_docker | Installs and configures Docker on Debian-based systems |
| install_azcli | Installs and configures the Azure CLI |
| install_runelite | Installs Java Runtime Environment (JRE) on Debian-based systems |
| install_jre | Creates an alias for launching RuneLite with 4k monitor support |
| create_alias | Creates a simple launcher script for RuneLite enabling 4K monitor with 2x zoom |
| verify_hashicorp_gpg_key | Downloads and verifies the HashiCorp GPG signing key by fetching the expected fingerprint from HashiCorp's website |
| add_hashicorp_repository | Adds the HashiCorp apt repository to the system's package sources |
| install_hashicorp_product | Installs a HashiCorp product after verifying the GPG key and adding the repository |
| install_packer | (legacy standalone) Installs HashiCorp's Packer and configures the system as a Packer build host. |
| install_vscode | Installs Visual Studio Code on a Debian-based system by adding the Microsoft repository and installing the package. |
| install_signal | Installs signal-desktop on Debian-based Linux distributions. |
| install_anything_llm | Downloads and runs the Anything LLM Docker container |
| set_venv | Quickly sets up a Python virtual environment in the current directory |
| ubuntu_postdeployment | This is a super function that combines all ui and software functions into 1 post deployment script. |
| install_tokyonight_gtk_theme | Installs and applies the Tokyonight GTK theme |
| set_gnome_fonts | Configures GNOME fonts and rendering settings |
| setup_gnome_extras | Installs GNOME Tweaks and useful shell extensions |
| install_juno_theme | Installs and applies the Juno GTK theme |
| jetbrains_font | Installs the JetBrains Mono font system-wide |
