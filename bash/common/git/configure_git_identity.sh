#!/bin/bash
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/common/git/configure_git_identity.sh) `

# Function: configure_git_identity
# Description: Pins a git identity to a workspace directory and routes GitHub credentials per owner.
#              Commits made anywhere under <workspace> always use the given name/email, and any remote
#              under github.com/<owner> always resolves credentials as <identity>, regardless of which
#              other GitHub accounts are configured on the machine.
# Usage: configure_git_identity [workspace] [owner...]
#        PDS_GIT_IDENTITY / PDS_GIT_NAME / PDS_GIT_EMAIL override the defaults.
configure_git_identity() {
    local identity="${PDS_GIT_IDENTITY:-michielvha}"
    local name="${PDS_GIT_NAME:-michielvha}"
    local email="${PDS_GIT_EMAIL:-michielvh@outlook.com}"
    local workspace="${1:-$HOME/code/personal}"
    shift 2>/dev/null

    local owners=("$@")
    [[ ${#owners[@]} -eq 0 ]] && owners=("michielvha" "vhco-pro")

    command -v git >/dev/null 2>&1 || { echo "❌ git is not installed"; return 1; }

    echo "🔧 Configuring git identity '$identity' for $workspace"

    # Strip a trailing slash so we control the exact form of the gitdir pattern below.
    workspace="${workspace%/}"
    mkdir -p "$workspace"

    local inc_dir="$HOME/.gitconfig.d"
    local inc_file="$inc_dir/${identity}.inc"
    mkdir -p "$inc_dir"

    # The include file holds everything that should apply *inside* the workspace.
    cat > "$inc_file" <<EOF
# Managed by PDS (configure_git_identity) - do not edit by hand.
[user]
	name = $name
	email = $email
[credential "https://github.com"]
	username = $identity
EOF
    echo "✅ Wrote $inc_file"

    # Use the ~ form when the workspace lives under \$HOME so the config stays portable
    # between hosts with different usernames. The trailing slash makes the pattern
    # recursive: it matches the directory and everything beneath it.
    local gitdir_pattern
    if [[ "$workspace" == "$HOME" || "$workspace" == "$HOME"/* ]]; then
        gitdir_pattern="gitdir:~${workspace#"$HOME"}/"
    else
        gitdir_pattern="gitdir:${workspace}/"
    fi

    git config --global --replace-all "includeIf.${gitdir_pattern}.path" "$inc_file"
    echo "✅ Bound $gitdir_pattern -> $inc_file"

    # Per-owner credential routing. This is global on purpose: it must apply even when a
    # repo is cloned outside the workspace, and git matches these sections against the
    # remote URL rather than the working directory.
    local owner
    for owner in "${owners[@]}"; do
        git config --global --replace-all "credential.https://github.com/${owner}.username" "$identity"
        echo "✅ github.com/${owner} -> $identity"
    done

    # Fall back to the same identity for anything on github.com that isn't matched above.
    git config --global --replace-all "credential.https://github.com.username" "$identity"

    # Only seed the machine-wide identity if the user hasn't already set one, so this is
    # safe to run on a host that is already configured for a different default account.
    git config --global user.name >/dev/null 2>&1 || git config --global user.name "$name"
    git config --global user.email >/dev/null 2>&1 || git config --global user.email "$email"

    echo "✅ Git identity configured."
}

# Function: show_git_identity
# Description: Shows which identity and credential username git resolves for a given repo path or URL.
#              Use this to verify configure_git_identity did what you expect.
# Usage: show_git_identity [repo_path] [url]
show_git_identity() {
    # NB: do not name this `path` - in zsh that is a special array tied to $PATH,
    # and assigning to it destroys command lookup for the rest of the function.
    local repo_path="${1:-$HOME/code/personal}"
    local url="${2:-https://github.com/michielvha/PDS.git}"

    mkdir -p "$repo_path"
    echo "📍 Identity resolved inside $repo_path:"
    git -C "$repo_path" config user.name 2>/dev/null | sed 's/^/   name:  /'
    git -C "$repo_path" config user.email 2>/dev/null | sed 's/^/   email: /'

    echo "🔑 Credential username resolved for $url:"
    git config --get-urlmatch credential.username "$url" 2>/dev/null | sed 's/^/   /' \
        || echo "   (none configured)"
}
