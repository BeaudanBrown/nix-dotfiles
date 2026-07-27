#!/usr/bin/env bash
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

if [[ -n $(git status --porcelain) ]]; then
	echo "test-installer-e2e requires a clean repository" >&2
	exit 1
fi

exec nix develop -c python tests/installer-e2e/run.py
