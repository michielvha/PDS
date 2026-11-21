#!/usr/bin/env bash
# Refuses a release run unless it is on an exact stable tag vMAJOR.MINOR.PATCH
# whose commit is on main. A workflow_dispatch ignores the tag filter, so this
# is what stops a dispatch on a prerelease tag, a tag outside main or a branch
# from publishing anything. Writes tag, version and release-url outputs.
#
# Needs: GITHUB_REF, GITHUB_SHA, GITHUB_REPOSITORY, GITHUB_SERVER_URL,
# GITHUB_OUTPUT, and a checkout with origin/main fetched.
set -euo pipefail

ref="${GITHUB_REF:?}"
number='(0|[1-9][0-9]*)'
if [[ ! "$ref" =~ ^refs/tags/v${number}\.${number}\.${number}$ ]]; then
  echo "::error::Refusing to release $ref: only an exact stable tag such as refs/tags/v1.2.3 publishes."
  exit 1
fi
tag="${ref#refs/tags/}"

git fetch --no-tags --quiet origin "+refs/heads/main:refs/remotes/origin/main"
if ! git merge-base --is-ancestor "${GITHUB_SHA:?}" refs/remotes/origin/main; then
  echo "::error::Refusing to release $tag: its commit $GITHUB_SHA is not on main."
  exit 1
fi

{
  echo "tag=$tag"
  echo "version=${tag#v}"
  echo "release-url=${GITHUB_SERVER_URL:?}/${GITHUB_REPOSITORY:?}/releases/tag/$tag"
} >> "${GITHUB_OUTPUT:?}"
echo "Releasing $tag from $GITHUB_SHA."
