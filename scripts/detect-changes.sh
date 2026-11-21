#!/usr/bin/env bash
# Decides which PDS check groups a push needs, so ci.yml runs only those:
#   powershell  pwsh/ or PSScriptAnalyzerSettings.psd1 changed
#   package     packaging/, bash/ or tests/ changed (ShellCheck, the .deb build and install tests)
# A change under .github/ or scripts/ selects both, and so does any event other than a push.
# A push is compared with the branch's previous tip; a new branch, or a force push whose
# previous tip is not in the new history, is compared with its merge base with main.
# Writes package=true|false and powershell=true|false to GITHUB_OUTPUT.
#
# Needs: EVENT_NAME, BEFORE (github.event.before), GITHUB_SHA, GITHUB_OUTPUT, and a checkout
# with full history. MAIN_REF overrides the main branch ref (default refs/remotes/origin/main).
set -euo pipefail

event="${EVENT_NAME:?}"
before="${BEFORE:-}"
head="${GITHUB_SHA:?}"
main_ref="${MAIN_REF:-refs/remotes/origin/main}"

emit() {
  printf 'package=%s\npowershell=%s\n' "$1" "$2" >> "${GITHUB_OUTPUT:?}"
  echo "package=$1 powershell=$2: $3"
}

if [[ "$event" != push ]]; then
  emit true true "a $event runs every check"
  exit 0
fi

if [[ -n "$before" && ! "$before" =~ ^0+$ ]] &&
  git cat-file -e "${before}^{commit}" 2>/dev/null &&
  git merge-base --is-ancestor "$before" "$head"; then
  base="$before"
  reason="changes since the previous tip ${before:0:7}"
elif base="$(git merge-base "$main_ref" "$head" 2>/dev/null)"; then
  reason="changes since the merge base with main ${base:0:7}"
else
  emit true true "no previous tip and no merge base with main, so every check runs"
  exit 0
fi

package=false
powershell=false
while IFS= read -r file; do
  case "$file" in
    .github/* | scripts/*) package=true; powershell=true ;;
    pwsh/* | PSScriptAnalyzerSettings.psd1) powershell=true ;;
    packaging/* | bash/* | tests/*) package=true ;;
  esac
done < <(git diff --name-only "$base" "$head")

emit "$package" "$powershell" "$reason"
