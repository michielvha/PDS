#!/bin/bash
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/debian/deploy/bootstrap.sh) `
#
# One entrypoint that takes a fresh Debian/Ubuntu workstation to a working dev machine:
# base packages -> dev stack -> GitHub auth -> repos cloned into the workspace.
#
# Quick start on a brand new host:
#   source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/debian/deploy/bootstrap.sh)
#   bootstrap_workstation

# --- configuration (override by exporting before calling) -------------------------------------
PDS_WORKSPACE="${PDS_WORKSPACE:-$HOME/code/personal}"
PDS_GIT_IDENTITY="${PDS_GIT_IDENTITY:-michielvha}"
PDS_GIT_NAME="${PDS_GIT_NAME:-michielvha}"
PDS_GIT_EMAIL="${PDS_GIT_EMAIL:-michielvh@outlook.com}"
PDS_GITHUB_OWNERS="${PDS_GITHUB_OWNERS:-michielvha vhco-pro}"
PDS_REF="${PDS_REF:-main}"

# Function: _pds_source
# Description: Sources a PDS library file, preferring the locally installed copy from the deb package
#              and falling back to GitHub raw. Unlike the bare `source <(curl ...)` pattern used
#              elsewhere in this repo, a failed fetch is reported instead of silently leaving the
#              function undefined until it is called.
_pds_source() {
	local rel="$1"
	local lib="${PDS_LIB_DIR:-/usr/share/pds}"
	local installed="${lib}/${rel#bash/}"

	if [[ -r "$installed" ]]; then
		# shellcheck disable=SC1090
		source "$installed"
		return 0
	fi

	local content
	content=$(curl -fsSL "https://raw.githubusercontent.com/michielvha/PDS/${PDS_REF}/${rel}") \
		|| { echo "❌ Failed to fetch $rel" >&2; return 1; }
	eval "$content" || { echo "❌ Failed to evaluate $rel" >&2; return 1; }
}

# Function: bootstrap_base
# Description: System update, core CLI packages, passwordless sudo and the shell environment.
bootstrap_base() {
	echo "═══ 1/4 base system ═══"

	_pds_source "bash/common/admin/sysadmin.sh"
	_pds_source "bash/common/shell/zsh.sh"
	_pds_source "bash/common/software/install_bat.sh"

	echo "⬆️  Updating system..."
	full_upgrade

	echo "📦 Installing core packages..."
	sudo apt-get install -y \
		git curl wget make jq yq unzip tree \
		ca-certificates gnupg pass \
		net-tools dnsutils \
		btop zsh openssh-server

	echo "🔐 Configuring passwordless sudo..."
	set_sudo_nopasswd "$USER"

	echo "🦇 Installing bat..."
	install_bat
	setup_bat_alias

	echo "🐚 Configuring zsh..."
	install_zi
	configure_zsh
	set_default_zsh

	echo "✅ Base system ready."
}

# Function: bootstrap_stack
# Description: Installs the development stack - containers, languages, kubernetes and cloud CLIs.
bootstrap_stack() {
	echo "═══ 2/4 dev stack ═══"

	_pds_source "bash/debian/software/install_docker.sh"
	_pds_source "bash/debian/software/install_kubectl.sh"
	_pds_source "bash/debian/software/install_vscode.sh"
	_pds_source "bash/common/software/go.sh"
	_pds_source "bash/common/software/node.sh"
	_pds_source "bash/common/cloud/azure.sh"
	_pds_source "bash/common/cloud/aws.sh"
	_pds_source "bash/common/software/install_claude_code.sh"

	install_docker
	install_go
	set_go_env
	install_node
	install_kubectl
	install_azcli
	install_aws_cli
	install_vscode
	install_claude_code

	echo "✅ Dev stack installed."
}

# Function: bootstrap_github
# Description: Installs the credential manager and GitHub CLI, logs in, and pins the workspace identity
#              so every commit under $PDS_WORKSPACE is authored and authenticated as $PDS_GIT_IDENTITY.
bootstrap_github() {
	echo "═══ 3/4 github auth ═══"

	_pds_source "bash/debian/software/install_gh.sh"
	_pds_source "bash/common/software/install_git_credman.sh"
	_pds_source "bash/common/git/github_auth.sh"
	_pds_source "bash/common/git/configure_git_identity.sh"

	install_gh
	install_git_credman

	# install_git_credman sets useHttpPath globally, which breaks per-owner credential reuse.
	scope_git_credman

	# shellcheck disable=SC2086 # word splitting is intentional - PDS_GITHUB_OWNERS is a list
	configure_git_identity "$PDS_WORKSPACE" $PDS_GITHUB_OWNERS

	github_login "$PDS_GIT_IDENTITY"
	sync_github_credentials "$PDS_GIT_IDENTITY"

	# shellcheck disable=SC2086
	verify_github_credentials $PDS_GITHUB_OWNERS

	echo "✅ GitHub configured."
}

# Function: bootstrap_repos
# Description: Clones all non-archived repositories for the configured owners into the workspace.
bootstrap_repos() {
	echo "═══ 4/4 repositories ═══"

	_pds_source "bash/common/git/clone_repos.sh"

	# shellcheck disable=SC2086
	clone_github_repos "$PDS_WORKSPACE" $PDS_GITHUB_OWNERS
}

# Function: bootstrap_workstation
# Description: Runs the full workstation bootstrap, or a single stage.
# Usage: bootstrap_workstation [all|base|stack|github|repos]
bootstrap_workstation() {
	local stage="${1:-all}"

	if [[ ! -f /etc/debian_version ]]; then
		echo "❌ This bootstrap targets Debian-based systems only."
		return 1
	fi

	echo "🚀 PDS workstation bootstrap"
	echo "   workspace: $PDS_WORKSPACE"
	echo "   identity:  $PDS_GIT_IDENTITY <$PDS_GIT_EMAIL>"
	echo "   owners:    $PDS_GITHUB_OWNERS"
	echo "   stage:     $stage"
	echo

	case "$stage" in
		base)   bootstrap_base ;;
		stack)  bootstrap_stack ;;
		github) bootstrap_github ;;
		repos)  bootstrap_repos ;;
		all)
			bootstrap_base   || { echo "❌ base stage failed"; return 1; }
			bootstrap_stack  || { echo "❌ stack stage failed"; return 1; }
			bootstrap_github || { echo "❌ github stage failed"; return 1; }
			bootstrap_repos  || echo "⚠️  some repositories failed to clone"
			;;
		*)
			echo "❌ Unknown stage: $stage"
			echo "Usage: bootstrap_workstation [all|base|stack|github|repos]"
			return 1
			;;
	esac

	echo
	echo "🎉 Bootstrap stage '$stage' complete."
	echo "📝 Log out and back in for the docker group and default shell to take effect."
}
