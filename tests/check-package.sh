#!/usr/bin/env bash
# Build an explicitly local candidate and test it in disposable Ubuntu.
set -euo pipefail
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
bash packaging/scripts/fetch-nfpm.sh "$work/tools"
export PATH="$work/tools:$PATH"
make -C packaging lint-image-provisioning
make -C packaging test-image-provisioning
