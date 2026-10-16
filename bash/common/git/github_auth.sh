#!/bin/bash
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/common/git/github_auth.sh) `

# Function: scope_git_credman
# Description: Corrects the global Git Credential Manager configuration for multi-account use.
#              install_git_credman sets `credential.useHttpPath = true` globally, which makes GCM key
#              every credential by full repo path - one stored secret per repository, and a fresh auth
#              prompt for every new clone. Azure DevOps genuinely needs it, GitHub does not, so this
#              narrows it to dev.azure.com and leaves owner-level routing to configure_git_identity.
scope_git_credman() {
    command -v git >/dev/null 2>&1 || { echo "❌ git is not installed"; return 1; }

    echo "🔧 Scoping Git Credential Manager configuration..."

    git config --global --unset-all credential.useHttpPath 2>/dev/null || true
    git config --global --replace-all "credential.https://dev.azure.com.useHttpPath" true

    # Make sure GCM treats github.com with its GitHub provider rather than generic basic auth.
    git config --global --replace-all "credential.https://github.com.provider" github

    echo "✅ useHttpPath narrowed to dev.azure.com"
}

# Function: github_login
# Description: Logs in to one or more GitHub accounts with the gh CLI, skipping accounts that already
#              have a valid token. Uses the browser/device-code flow.
# Usage: github_login [account...]   (defaults to michielvha)
github_login() {
    command -v gh >/dev/null 2>&1 || { echo "❌ gh is not installed - run install_gh first"; return 1; }

    local accounts=("$@")
    [[ ${#accounts[@]} -eq 0 ]] && accounts=("michielvha")

    local account
    for account in "${accounts[@]}"; do
        if gh auth token -u "$account" >/dev/null 2>&1; then
            echo "ℹ️  Already authenticated as $account"
            continue
        fi

        echo "🔐 Logging in to GitHub as $account..."
        echo "   (pick '$account' when prompted for the account)"
        gh auth login --hostname github.com --git-protocol https --scopes 'repo,read:org,workflow,gist' \
            || { echo "❌ Login failed for $account"; return 1; }
    done

    echo "✅ GitHub authentication complete."
}

# Function: sync_github_credentials
# Description: Copies live gh CLI tokens into git's configured credential store (GCM), keyed per account.
#              gh keeps its tokens in its own keyring, which git never reads - so without this step git
#              falls through to whichever account owns the generic github.com entry and fails as the wrong
#              user. Re-run this whenever `gh auth login`/`refresh` has invalidated a stored token.
# Usage: sync_github_credentials [account...]   (defaults to michielvha)
sync_github_credentials() {
    command -v gh >/dev/null 2>&1 || { echo "❌ gh is not installed - run install_gh first"; return 1; }
    command -v git >/dev/null 2>&1 || { echo "❌ git is not installed"; return 1; }

    local accounts=("$@")
    [[ ${#accounts[@]} -eq 0 ]] && accounts=("michielvha")

    local account token
    for account in "${accounts[@]}"; do
        token=$(gh auth token -u "$account" 2>/dev/null)
        if [[ -z "$token" ]]; then
            echo "⚠️  No gh token for $account - skipping (run github_login $account)"
            continue
        fi

        # `git credential approve` writes through whatever helper is configured, so this works
        # with GCM/gpg on Linux and osxkeychain on macOS without knowing the store layout.
        printf 'protocol=https\nhost=github.com\nusername=%s\npassword=%s\n\n' "$account" "$token" \
            | git credential approve \
            && echo "✅ Stored credential for $account" \
            || echo "❌ Failed to store credential for $account"
    done
}

# Function: verify_github_credentials
# Description: Asks git which credential it would actually use for a given owner's repo. Prints the
#              resolved username so you can confirm the routing rather than discovering it on a push.
# Usage: verify_github_credentials [owner...]   (defaults to michielvha vhco-pro)
verify_github_credentials() {
    local owners=("$@")
    [[ ${#owners[@]} -eq 0 ]] && owners=("michielvha" "vhco-pro")

    local owner resolved
    for owner in "${owners[@]}"; do
        resolved=$(printf 'protocol=https\nhost=github.com\npath=%s/probe.git\n\n' "$owner" \
            | git credential fill 2>/dev/null | grep '^username=' | cut -d= -f2)
        if [[ -n "$resolved" ]]; then
            echo "✅ github.com/$owner -> $resolved"
        else
            echo "❌ github.com/$owner -> could not resolve a credential"
        fi
    done
}
