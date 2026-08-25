#!/bin/bash
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/common/git/clone_repos.sh) `

# Function: clone_github_repos
# Description: Clones every non-archived repository owned by the given GitHub owners into a flat
#              workspace directory. Existing clones are left untouched, so this is safe to re-run on
#              an already-populated workstation. Cloning is done with an explicit gh token so a bulk
#              run never trips the credential manager once per repo.
# Usage: clone_github_repos [workspace] [owner...]
#        PDS_GIT_IDENTITY selects which gh account's token is used (default michielvha).
clone_github_repos() {
    local workspace="${1:-$HOME/code/personal}"
    shift 2>/dev/null

    local owners=("$@")
    [[ ${#owners[@]} -eq 0 ]] && owners=("michielvha" "vhco-pro")

    local identity="${PDS_GIT_IDENTITY:-michielvha}"

    command -v gh >/dev/null 2>&1 || { echo "❌ gh is not installed - run install_gh first"; return 1; }

    local token
    token=$(gh auth token -u "$identity" 2>/dev/null)
    [[ -n "$token" ]] || { echo "❌ No gh token for $identity - run github_login $identity first"; return 1; }

    mkdir -p "$workspace"

    local cloned=0 skipped=0 failed=0
    # Declare every local once, up front: re-declaring a bare `local` inside the loop makes
    # zsh echo the variable's current value, and these functions are auto-loaded into zsh.
    local owner repo name repos count

    for owner in "${owners[@]}"; do
        echo "📚 Listing non-archived repositories for $owner..."

        repos=$(GH_TOKEN="$token" gh repo list "$owner" --no-archived --limit 500 \
            --json nameWithOwner --jq '.[].nameWithOwner' 2>/dev/null)

        if [[ -z "$repos" ]]; then
            echo "⚠️  No repositories returned for $owner (no access, or none exist)"
            continue
        fi

        count=$(grep -c . <<< "$repos")
        echo "   found $count repositories"

        while IFS= read -r repo; do
            [[ -n "$repo" ]] || continue
            name="${repo#*/}"

            if [[ -d "$workspace/$name/.git" ]]; then
                skipped=$((skipped + 1))
                continue
            fi

            if [[ -e "$workspace/$name" ]]; then
                echo "⚠️  $name exists but is not a git repo - skipping"
                skipped=$((skipped + 1))
                continue
            fi

            printf '⬇️  %s ... ' "$repo"
            if GH_TOKEN="$token" gh repo clone "$repo" "$workspace/$name" -- --quiet 2>/dev/null; then
                echo "ok"
                cloned=$((cloned + 1))
            else
                echo "failed"
                failed=$((failed + 1))
            fi
        done <<< "$repos"
    done

    echo
    echo "✅ Clone summary: $cloned cloned, $skipped already present, $failed failed"
    echo "📂 Workspace: $workspace"
    [[ "$failed" -eq 0 ]]
}
