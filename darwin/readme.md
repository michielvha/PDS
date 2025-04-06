# Darwin-Based Systems Setup Guide

This guide provides instructions and utilities specific to Darwin (macOS) environments.

## 📦 Software Packages

We use [Homebrew](https://brew.sh) as the primary package manager. The [`install.sh`](install.sh) script installs the following applications:

- Arc Browser
- Warp Terminal
- iTerm2
- GitHub CLI (`gh`)
- Go
- Neofetch
- kubectl
- Helm
- Kustomize
- Visual Studio Code
- ChatGPT
- Tailscale

## Functions

Available setup [functions](functions.sh):

- `setup_go_env` – Configures Go-related environment variables and paths.
- `setup_zsh` – Sets up the Zsh shell. This includes:
  - `install_zi` – Installs the ZI plugin manager.
  - `configure_zsh` – Applies the Zsh configuration.

## ⌨️ Shortcuts

- `command + q` - actually quit apps (red cross doesn't behave like on windows).
- ` Ctrl + `` (backtick) ` -  quickly open a terminal in VSCode.

### VSCode
- `Option (⌥) + Shift (⇧) + A` - Block Comment Shortcut
- `Option (⌥) + space` - call chatGPT from vscode

## 🔣 Special Characters (macOS Shortcuts)

- `Option (⌥) + n` → **~ (Tilde)**
- `Option (⌥) + Shift (⇧) + /` → **\\ (Backslash)**
- `Option (⌥) + Shift (⇧) + L` → **| (Pipe)**
- `Option (⌥) + Shift (⇧) + (` → **[ (Left Square Bracket)**
- `Option (⌥) + Shift (⇧) + )` → **] (Right Square Bracket)**
- `Option (⌥) + (` → **{ (Left Curly Brace)**
- `Option (⌥) + )` → **} (Right Curly Brace)**

## ZSH Setup

1. Install a compatible font for the Powerlevel10k prompt:
   [Manual Font Installation Guide](https://github.com/romkatv/powerlevel10k?tab=readme-ov-file#manual-font-installation)

2. Run the `setup_zsh` function to configure Zsh and apply prompt settings.

## Recommended VSCode Extensions

- Markdown All-in-One
- TODO Tree / TODO Highlight
- Go (Official Extension)

