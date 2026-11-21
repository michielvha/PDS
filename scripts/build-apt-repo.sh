#!/usr/bin/env bash
# Builds the signed APT repository for GitHub Pages from scratch: the .deb of
# every published (non-draft) GitHub Release, plus this run's .deb when the tag
# has no Release yet. Nothing is cached, so the index always matches the
# Releases, and rerunning the job after the Release exists gives the same index.
#
# Usage: build-apt-repo.sh <run-deb-dir> <output-dir>
# Needs: TAG, GITHUB_REPOSITORY, GITHUB_REPOSITORY_OWNER, GH_TOKEN,
# GPG_PRIVATE_KEY and optionally GPG_PASSPHRASE; aptly, gpg, gh and jq on PATH.
set -euo pipefail

run_debs="${1:?usage: build-apt-repo.sh <run-deb-dir> <output-dir>}"
out="${2:?usage: build-apt-repo.sh <run-deb-dir> <output-dir>}"
repo="${GITHUB_REPOSITORY:?}"
tag="${TAG:?}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# A throwaway keyring, so the signing key never lands in the runner's home.
export GNUPGHOME="$work/gnupg"
mkdir -m 700 "$GNUPGHOME"
printf '%s\n' batch 'pinentry-mode loopback' > "$GNUPGHOME/gpg.conf"
printf '%s\n' "${GPG_PRIVATE_KEY:?}" | gpg --batch --import
gpg --export > "$work/pds-repo.gpg"
gpg --list-secret-keys --keyid-format LONG | grep -E '^(sec|ssb)'

passphrase=()
if [[ -n "${GPG_PASSPHRASE:-}" ]]; then
  passphrase=("-passphrase=$GPG_PASSPHRASE")
fi

printf '{"rootDir": "%s"}\n' "$work/aptly" > "$work/aptly.conf"
aptly=(aptly "-config=$work/aptly.conf")

released="$(gh api --paginate "repos/$repo/releases" --jq '.[] | select(.draft | not) | .tag_name')"
with_deb="$(gh api --paginate "repos/$repo/releases" \
  --jq '.[] | select(.draft | not) | select(any(.assets[]; .name | endswith(".deb"))) | .tag_name')"

mkdir -p "$work/debs"
while read -r release; do
  [[ -n "$release" ]] || continue
  echo "Adding the .deb of Release $release"
  gh release download "$release" --repo "$repo" --pattern '*.deb' --dir "$work/debs/$release"
done <<< "$with_deb"

if grep -Fxq -- "$tag" <<< "$released"; then
  echo "$tag already has a Release; its own .deb is in the index."
else
  echo "$tag has no Release yet; adding this run's .deb."
  mkdir -p "$work/debs/$tag"
  cp "$run_debs"/*.deb "$work/debs/$tag/"
fi

"${aptly[@]}" repo create -distribution=stable -component=main pds
"${aptly[@]}" repo add pds "$work/debs"
"${aptly[@]}" repo show -with-packages pds
"${aptly[@]}" publish repo -distribution=stable -architectures=all -batch=false "${passphrase[@]}" pds

mkdir -p "$out/apt"
cp -r "$work/aptly/public/." "$out/apt/"
cp "$work/pds-repo.gpg" "$out/apt/pds-repo.gpg"
cp "$work/pds-repo.gpg" "$out/pds-repo.gpg"
cp "$root/.github/pages/logo.png" "$out/logo.png"
sed -e "s/{{REPO_OWNER}}/${GITHUB_REPOSITORY_OWNER:?}/g" \
  -e "s|{{REPO}}|$repo|g" \
  "$root/.github/pages/index.html" > "$out/index.html"
ls -la "$out" "$out/apt"
