#!/bin/bash
# Source: ` source <(curl -fsSL https://raw.githubusercontent.com/michielvha/PDS/main/bash/common/utils/git.sh) `

# Function: fix_big_files_already_comitted
# Description: Solve the issue when a file that was to big is already in git history.
fix_big_files_already_comitted() {
    echo "🔧 Fixing large files already committed in Git..."

    # Check if the .git directory exists
    if [ ! -d .git ]; then
        echo "❌ No Git repository found. Please run this script in a Git repository."
        return 1
    fi

    # Make sure Git LFS is ready (once per machine)
    # git lfs install

    # 1) Tell LFS which kinds of files belong there
    # git lfs track "*.zip"
    # git lfs track "*.iso"
    # git add .gitattributes
    # git commit -m "Track .zip and .iso with Git LFS"

    # 2) Rewrite every commit so the real data moves to LFS
    git lfs migrate import --include="*.zip,*.iso" --everything

    # 3) Push the LFS objects, then the new history
    git lfs push --all origin            # uploads the binaries
    git push # --force-with-lease          # updates every branch/tag

}