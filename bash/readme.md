# Bash module

## TODO

- Create a wrapper function to determine which distro we use and which architecture we are on. because this is required by so many of the install functions it seems only right we wrap it instead of implementing it in each script where it is required

## Architecture

The PDS Bash module is designed to provide an extensible and organized file structure for managing a wide range of Bash functions. These functions are tailored to streamline the setup and configuration of development environments, making it easier for developers and system administrators to automate repetitive tasks and maintain consistency across systems.

## Purpose

The primary goal of this module is to:

- **Simplify Environment Setup**: Provide pre-defined scripts for installing software, configuring environments, and managing system settings.
- **Enhance Reusability**: Offer a modular structure where functions can be easily imported and reused across different projects.
- **Ensure Consistency**: Standardize the way environments are configured, reducing errors and improving reliability.

## Coding style

where possible I prefer using `conditional execution / short-circuit evaluation` to keep the code concise.

**Example:**
```shell
# Pattern: condition && success_action || failure_action
id "$ADMIN" &>/dev/null && echo "exists" || echo "doesn't exist"

# Equivalent to:
if id "$ADMIN" &>/dev/null; then
    echo "exists"
else
    echo "doesn't exist"
fi
```

it's clean, readable, and efficient!

ofcourse it's only possible if the second statement after the && will always return true, else we should use the full if/else notation.

## Features

- **Modular Design**: Functions are organized into directories based on their purpose, such as `common`, `debian`, and `fedora`, making it easy to locate and manage them.
- **Documentation**: Each function is documented with its purpose, usage, and description, ensuring clarity and ease of use.
- **Cross-Platform Support**: Scripts are tailored for different operating systems, including Fedora and Debian-based Linux distributions.
- **Dynamic Importing**: Functions can be imported either temporarily (ephemeral) or persistently, depending on the use case.

## Enhancements

- **Create a custom bash package manager** using Golang to enhance the way we currently have to source all the files from different urls.

## Getting Started

To get started with the PDS Bash module, you can explore the directories to find the functions you need. Each function is defined in a `.sh` file and follows a consistent format for easy understanding and integration.

### Example Function Format

```bash
#!/bin/bash
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/path/file.sh) `

# Function: function_name
# Description: This is what the function does
# usage: if any
function_name() {}
```

### Importing Functions

#### Ephemeral Import

For temporary use, you can fetch and source functions directly from the repository:

```bash
source <(curl -fsSL "https://raw.githubusercontent.com/michielvha/PDS/main/bash/common/software/go.sh")
```

#### Persistent Import

For long-term use, you can download and source functions into a local directory:

```bash
MODULE_PATH="$HOME/.bash_modules"
REPO_URL="https://raw.githubusercontent.com/michielvha/PDS/main/bash/debian/software/"
MODULES=("install.sh" "sysadmin.sh" "rke2.sh" "public.sh" "utils.sh")

mkdir -p "$MODULE_PATH"

for module in "${MODULES[@]}"; do
    curl -fsSL "$REPO_URL/$module" -o "$MODULE_PATH/$module" || { echo "Failed to download $module"; exit 1; }
    source "$MODULE_PATH/$module"
done
```

## List of Functions

The module includes a variety of functions categorized by their purpose. Use the provided script to generate a detailed list of functions and their descriptions.

```bash
# Function to process files in a directory and append to readme.md
process_directory() {
    local dir_name=$1
    local dir_path=$2
    
    # Add section header for the directory
    echo -e "\n## ${dir_name} Functions\n" >> readme.md
    echo -e "| Function | Description |\n|---|---|" >> readme.md
    
    # Find all .sh files in the directory and process them
    find "${dir_path}" -type f -name "*.sh" | while read file; do
        awk '
        /# Function:/ {function_name=$3}
        /# Description:/ && function_name {
            # Extract the description text
            description=substr($0, index($0, ":") + 1)
            # Remove leading spaces
            gsub(/^[ \t]+/, "", description)
            # Print the function and description in table format
            printf "| %s | %s |\n", function_name, description
            function_name=""
        }' "$file" >> readme.md
    done
}

# Process each directory
process_directory "Debian" "./debian"
process_directory "Common" "./common"
process_directory "Fedora" "./fedora"

# Display the result
cat readme.md
```

## Debian Functions

| Function | Description |
|---|---|
| install_zen | Installs Zen Browser |
| install_librewolf | Installs librewolf browser |
| install_kubectl | Installs and configures kubectl |
| install_nvidia_ctk | Installs Nvidia container toolkit for container GPU support |
| install_git_cm | Downloads and installs the git-credential-manager (GCM) for Linux with proper setup for headless/TTY environments using GPG encryption. |
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

## Common Functions

| Function | Description |
|---|---|
| install_go | Installs the latest version of Golang and configures the environment for the current user. |
| set_go_env | Configures the Go environment variables for the current user. |
| setup_edgectl_dev_env | Sets up the development environment for edgectl with Go installed for the root user. Using root user because edgectl requires root privileges to run. |
| install_minikube | Installs the latest version of minikube. |
| get_latest_github_binary | Downloads and installs the latest release of a binary from a specified GitHub repository. |
| install_aws_cli | Installs and configures the AWS CLI |
| install_azcli | Installs and configures the Azure CLI |
| install_zi | Installs and configures Zi, a package manager for ZSH |
| configure_zsh | Configures ZSH using Zi with plugins and settings for an enhanced shell experience |
| set_default_zsh | Sets ZSH as the default shell for the current user |
| install_nerd_fonts | Install the recommended fonts for Powerlevel10k and configure GNOME Terminal to use them |
| pre_commit_hook | Pre-commit hook that automatically formats Go code using gofumpt |