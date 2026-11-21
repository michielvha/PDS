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
mkdir -p pwsh packaging bash tests .github scripts docs
for f in pwsh/a.ps1 packaging/a bash/a.sh tests/a.sh .github/a.yml scripts/a.sh docs/a.md readme.md PSScriptAnalyzerSettings.psd1; do
  echo base > "$f"
done
git add -A && git commit -qm base
git update-ref refs/remotes/origin/main HEAD
base_commit="$(git rev-parse HEAD)"

# Commits one change to each named file on top of the given commit and prints the new commit.
commit_on() {
  local parent="$1"; shift
  git checkout -q --detach "$parent"
  for f in "$@"; do echo "change $RANDOM" >> "$f"; done
  git add -A && git commit -qm change
  git rev-parse HEAD
}

# check <name> <event> <before> <head> <expected package> <expected powershell>
check() {
  local name="$1" event="$2" before="$3" head="$4" want_package="$5" want_powershell="$6" out
  out="$(mktemp)"
  EVENT_NAME="$event" BEFORE="$before" GITHUB_SHA="$head" GITHUB_OUTPUT="$out" bash "$script" > /dev/null
  local got_package got_powershell
  got_package="$(sed -n 's/^package=//p' "$out")"
  got_powershell="$(sed -n 's/^powershell=//p' "$out")"
  if [[ "$got_package" == "$want_package" && "$got_powershell" == "$want_powershell" ]]; then
    echo "ok: $name"
  else
    echo "FAIL: $name (package=$got_package powershell=$got_powershell, expected $want_package/$want_powershell)"
    failures=$((failures + 1))
  fi
}

check 'powershell only' push "$base_commit" "$(commit_on "$base_commit" pwsh/a.ps1)" false true
check 'analyzer settings' push "$base_commit" "$(commit_on "$base_commit" PSScriptAnalyzerSettings.psd1)" false true
check 'packaging only' push "$base_commit" "$(commit_on "$base_commit" packaging/a)" true false
check 'bash only' push "$base_commit" "$(commit_on "$base_commit" bash/a.sh)" true false
check 'package tests only' push "$base_commit" "$(commit_on "$base_commit" tests/a.sh)" true false
check 'documentation only' push "$base_commit" "$(commit_on "$base_commit" docs/a.md readme.md)" false false
check 'workflow change' push "$base_commit" "$(commit_on "$base_commit" .github/a.yml)" true true
check 'script change' push "$base_commit" "$(commit_on "$base_commit" scripts/a.sh)" true true
check 'powershell and packaging' push "$base_commit" "$(commit_on "$base_commit" pwsh/a.ps1 bash/a.sh)" true true

# Only the commits since the previous tip count.
first="$(commit_on "$base_commit" bash/a.sh)"
second="$(commit_on "$first" pwsh/a.ps1)"
check 'second push of a branch' push "$first" "$second" false true

# A new branch has no previous tip: it is compared with its merge base with main.
check 'new branch' push 0000000000000000000000000000000000000000 "$second" true true

# A force push whose previous tip is not in the new history falls back to the merge base.
rewritten="$(commit_on "$base_commit" pwsh/a.ps1)"
check 'force push' push "$second" "$rewritten" false true
check 'unknown previous tip' push 1111111111111111111111111111111111111111 "$rewritten" false true

check 'dispatch' workflow_dispatch '' "$rewritten" true true

if (( failures > 0 )); then
  echo "$failures case(s) failed"
  exit 1
fi
echo 'all cases passed'
