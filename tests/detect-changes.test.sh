#!/usr/bin/env bash
# Behaviour tests for scripts/detect-changes.sh over throwaway Git histories.
# Run from anywhere: bash tests/detect-changes.test.sh
set -euo pipefail

script="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/detect-changes.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
failures=0

git init -q -b main "$work/repo"
cd "$work/repo"
git config user.email test@example.invalid
git config user.name test
mkdir -p pwsh/docs packaging bash tests .github scripts docs darwin
for f in pwsh/a.ps1 pwsh/docs/a.md packaging/a bash/a.sh tests/a.sh .github/a.yml scripts/a.sh docs/a.md readme.md darwin/a.ps1 PSScriptAnalyzerSettings.psd1; do
  echo base > "$f"
done
git add -A && git commit -qm base
git update-ref refs/remotes/origin/main HEAD
main_tip="$(git rev-parse HEAD)"

# Commits one change to each named file on top of the given commit and prints the new commit.
commit_on() {
  local parent="$1"; shift
  git checkout -q --detach "$parent"
  for f in "$@"; do echo "change $RANDOM" >> "$f"; done
  git add -A && git commit -qm change
  git rev-parse HEAD
}

# check <name> <event> <branch> <head> <package> <powershell> <workflows> [env assignments...]
check() {
  local name="$1" event="$2" branch="$3" head="$4" want="$5 $6 $7" out got
  shift 7
  out="$(mktemp)"
  env "$@" EVENT_NAME="$event" GITHUB_REF_NAME="$branch" GITHUB_SHA="$head" GITHUB_OUTPUT="$out" \
    bash "$script" > /dev/null
  got="$(sed -n 's/^package=//p' "$out") $(sed -n 's/^powershell=//p' "$out") $(sed -n 's/^workflows=//p' "$out")"
  if [[ "$got" == "$want" ]]; then
    echo "ok: $name"
  else
    echo "FAIL: $name (got $got, expected $want)"
    failures=$((failures + 1))
  fi
}

# A branch is judged on its whole diff from its merge base with main.
check 'powershell only' push feature "$(commit_on "$main_tip" pwsh/a.ps1)" false true false
check 'analyzer settings' push feature "$(commit_on "$main_tip" PSScriptAnalyzerSettings.psd1)" false true false
check 'packaging only' push feature "$(commit_on "$main_tip" packaging/a)" true false false
check 'bash only' push feature "$(commit_on "$main_tip" bash/a.sh)" true false false
check 'package tests only' push feature "$(commit_on "$main_tip" tests/a.sh)" true false false
check 'documentation with readme.md' push feature "$(commit_on "$main_tip" docs/a.md readme.md)" false false false
check 'markdown under pwsh/' push feature "$(commit_on "$main_tip" pwsh/docs/a.md)" false false false
check 'powershell file outside pwsh/' push feature "$(commit_on "$main_tip" darwin/a.ps1)" false true false
check 'workflow change' push feature "$(commit_on "$main_tip" .github/a.yml)" true true true
check 'script change' push feature "$(commit_on "$main_tip" scripts/a.sh)" true true false

# A later push of a branch still covers what its earlier pushes changed.
first="$(commit_on "$main_tip" bash/a.sh)"
second="$(commit_on "$first" pwsh/a.ps1)"
third="$(commit_on "$second" docs/a.md)"
check 'later push of a branch' push feature "$second" true true false
check 'documentation push on a branch with code' push feature "$third" true true false

# A force push is judged on its new diff from main: dropping the bash/ change drops its checks.
check 'force push that drops a bash/ change' push feature "$(commit_on "$main_tip" pwsh/a.ps1)" false true false

# main is judged on everything since the latest stable tag it contains that has a Release.
released="$(commit_on "$main_tip" bash/a.sh)"
git tag v1.2.3 "$released"
git tag v1.2.10 "$released"
prerelease="$(commit_on "$released" pwsh/a.ps1)"
git tag v1.3.0-rc.1 "$prerelease"
merged="$(commit_on "$prerelease" docs/a.md)"
published=$'v1.2.3\nv1.2.10\nv1.3.0-rc.1'
check 'main since the latest released stable tag' push main "$merged" false true false "PUBLISHED_TAGS=$published"
check 'main with only documentation since the tag' push main "$(commit_on "$released" docs/a.md)" false false false "PUBLISHED_TAGS=$published"

# A newer stable tag whose release failed has no Release: main is judged from the older one.
failed="$(commit_on "$released" packaging/a)"
git tag v1.2.11 "$failed"
after_failed="$(commit_on "$failed" docs/a.md)"
check 'main after a tag whose release failed' push main "$after_failed" true false false "PUBLISHED_TAGS=$published"

# Anything the script cannot judge runs every check.
check 'main without a released stable tag' push main "$merged" true true true PUBLISHED_TAGS=
check 'branch without a main ref' push feature "$(commit_on "$main_tip" docs/a.md)" true true true MAIN_REF=refs/remotes/origin/missing
check 'dispatch' workflow_dispatch feature "$third" true true true

if (( failures > 0 )); then
  echo "$failures case(s) failed"
  exit 1
fi
echo 'all cases passed'
