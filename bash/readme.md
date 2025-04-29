# Architecture

The PDS Bash module is designed to provide an extensible and organized file structure for managing a wide range of Bash functions. These functions are tailored to streamline the setup and configuration of development environments, making it easier for developers and system administrators to automate repetitive tasks and maintain consistency across systems.

## Purpose

The primary goal of this module is to:

- **Simplify Environment Setup**: Provide pre-defined scripts for installing software, configuring environments, and managing system settings.
- **Enhance Reusability**: Offer a modular structure where functions can be easily imported and reused across different projects.
- **Promote Collaboration**: Maintain a centralized repository of well-documented and tested functions that can be shared among team members.
- **Ensure Consistency**: Standardize the way environments are configured, reducing errors and improving reliability.

## Features

- **Modular Design**: Functions are organized into directories based on their purpose, such as `common`, `debian`, and `darwin`, making it easy to locate and manage them.
- **Documentation**: Each function is documented with its purpose, usage, and description, ensuring clarity and ease of use.
- **Cross-Platform Support**: Scripts are tailored for different operating systems, including macOS (`darwin`) and Debian-based Linux distributions.
- **Dynamic Importing**: Functions can be imported either temporarily (ephemeral) or persistently, depending on the use case.

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
