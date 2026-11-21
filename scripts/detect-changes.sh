#!/usr/bin/env bash
# Decides which PDS check groups a push needs, so ci.yml runs only those:
#   powershell  pwsh/ or PSScriptAnalyzerSettings.psd1 changed
#   package     packaging/, bash/ or tests/ changed (ShellCheck, the .deb build and install tests)
#   workflows   .github/ changed (actionlint); it also selects both groups above
# scripts/ selects powershell and package. Anything else is documentation and selects nothing.
#
# A branch is judged on its whole diff from its merge base with main, so a later push still runs
# the checks for everything the branch changed. main is judged on everything since the latest
# stable vX.Y.Z tag it contains, so a tag follows only passing checks for its release range.
# Any event other than a push, and any base that cannot be resolved, selects every group.
# Writes package, powershell and workflows (true|false) to GITHUB_OUTPUT.
#
# Needs: EVENT_NAME, GITHUB_REF_NAME, GITHUB_SHA, GITHUB_OUTPUT and a checkout with full
# history and tags. DEFAULT_BRANCH (default main) and MAIN_REF (default
# refs/remotes/origin/<default branch>) can be overridden.
set -euo pipefail

event="${EVENT_NAME:?}"
branch="${GITHUB_REF_NAME:?}"
head="${GITHUB_SHA:?}"
default_branch="${DEFAULT_BRANCH:-main}"
main_ref="${MAIN_REF:-refs/remotes/origin/$default_branch}"

emit() {
  printf 'package=%s\npowershell=%s\nworkflows=%s\n' "$1" "$2" "$3" >> "${GITHUB_OUTPUT:?}"
  echo "package=$1 powershell=$2 workflows=$3: $4"
}

every() {
  emit true true true "$1, so every check runs"
  exit 0
}

[[ "$event" == push ]] || every "a $event"

if [[ "$branch" == "$default_branch" ]]; then
  number='(0|[1-9][0-9]*)'
  tag="$(git tag --merged "$head" --list 'v*' | grep -E "^v${number}\.${number}\.${number}$" | sort -V | tail -n 1 || true)"
  [[ -n "$tag" ]] || every "$default_branch contains no stable tag"
  base="$(git rev-list -n 1 "$tag")"
  reason="changes since $tag"
else
  base="$(git merge-base "$main_ref" "$head" 2>/dev/null)" || every "no merge base with $default_branch"
  reason="changes since the merge base with $default_branch ${base:0:7}"
fi

package=false
powershell=false
workflows=false
while IFS= read -r file; do
  case "$file" in
    .github/*) package=true; powershell=true; workflows=true ;;
    scripts/*) package=true; powershell=true ;;
    pwsh/* | PSScriptAnalyzerSettings.psd1) powershell=true ;;
    packaging/* | bash/* | tests/*) package=true ;;
  esac
done < <(git diff --name-only "$base" "$head")

emit "$package" "$powershell" "$workflows" "$reason"
