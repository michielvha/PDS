#!/bin/bash


process_directory() {
    local dir_name=$1
    local dir_path=$2
    
    # Add section header for the directory
    echo -e "\n## ${dir_name} Functions\n" >> function_list.md
    echo -e "| Function | Description |\n|---|---|" >> function_list.md
    
    # Find all .sh files in the directory and process them
    find "${dir_path}" -type f -name "*.sh" | while read -r file; do
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
        }' "$file" >> function_list.md
    done
}

# Process each directory
process_directory "Debian" "./debian"
process_directory "Common" "./common"
process_directory "Fedora" "./fedora"

# Display the result
cat function_list.md