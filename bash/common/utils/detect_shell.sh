#!/bin/bash
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/common/utils/detect_shell.sh) `

# Function: detect_configured_shells
# Description: Detects shells that have configuration files in the user's home directory.
#              Returns a space-separated list of shell names (e.g., "bash zsh fish").
#              Only detects shells that have been configured (have config files).
# Usage: detect_configured_shells
detect_configured_shells() {
	local shells=()
	local home_dir="${HOME:-~}"
	
	# Check for common shell configuration files
	if [[ -f "$home_dir/.bashrc" ]] || [[ -f "$home_dir/.bash_profile" ]] || [[ -f "$home_dir/.bash_login" ]]; then
		shells+=("bash")
	fi
	[[ -f "$home_dir/.zshrc" ]] && shells+=("zsh")
	[[ -f "$home_dir/.config/fish/config.fish" ]] && shells+=("fish")
	[[ -f "$home_dir/.kshrc" ]] && shells+=("ksh")
	[[ -f "$home_dir/.cshrc" ]] && shells+=("csh")
	[[ -f "$home_dir/.tcshrc" ]] && shells+=("tcsh")
	[[ -f "$home_dir/.shrc" ]] && shells+=("sh")
	
	# Output space-separated list
	echo "${shells[*]}"
}

# Function: detect_installed_shells
# Description: Detects shells that have binaries installed in standard system paths.
#              Uses command -v to check for shell binaries in $PATH.
#              Returns a space-separated list of shell names (e.g., "bash zsh fish").
#              Detects shells that are installed but may not be configured.
# Usage: detect_installed_shells
detect_installed_shells() {
	local shells=()
	
	# Check for common shell binaries using command -v (most reliable method)
	local shell_binaries=(
		"bash"
		"zsh"
		"fish"
		"ksh"
		"csh"
		"tcsh"
		"dash"
	)
	
	for shell in "${shell_binaries[@]}"; do
		if command -v "$shell" >/dev/null 2>&1; then
			shells+=("$shell")
		fi
	done
	
	# Check for sh separately (only if bash is not found, as sh is often a symlink to bash/dash)
	if command -v sh >/dev/null 2>&1; then
		# Only add sh if bash is not in the list (sh is usually a symlink)
		if [[ ! " ${shells[*]} " =~ " bash " ]]; then
			shells+=("sh")
		fi
	fi
	
	# Output space-separated list
	echo "${shells[*]}"
}

# Function: get_shell_config_file
# Description: Returns the configuration file path for a given shell in the user's home directory.
#              Returns empty string if the shell config file doesn't exist.
# Usage: get_shell_config_file <shell_name>
# Example: get_shell_config_file "bash" -> "$HOME/.bashrc"
get_shell_config_file() {
	local shell="$1"
	local home_dir="${HOME:-~}"
	
	case "$shell" in
		bash)
			if [[ -f "$home_dir/.bashrc" ]]; then
				echo "$home_dir/.bashrc"
			elif [[ -f "$home_dir/.bash_profile" ]]; then
				echo "$home_dir/.bash_profile"
			elif [[ -f "$home_dir/.bash_login" ]]; then
				echo "$home_dir/.bash_login"
			fi
			;;
		zsh)
			[[ -f "$home_dir/.zshrc" ]] && echo "$home_dir/.zshrc"
			;;
		fish)
			[[ -f "$home_dir/.config/fish/config.fish" ]] && echo "$home_dir/.config/fish/config.fish"
			;;
		ksh)
			[[ -f "$home_dir/.kshrc" ]] && echo "$home_dir/.kshrc"
			;;
		csh)
			[[ -f "$home_dir/.cshrc" ]] && echo "$home_dir/.cshrc"
			;;
		tcsh)
			[[ -f "$home_dir/.tcshrc" ]] && echo "$home_dir/.tcshrc"
			;;
		sh|dash)
			[[ -f "$home_dir/.shrc" ]] && echo "$home_dir/.shrc"
			;;
	esac
}

