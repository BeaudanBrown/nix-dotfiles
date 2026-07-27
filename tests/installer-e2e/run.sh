#!/usr/bin/env bash
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

if [[ -n $(git status --porcelain) ]]; then
	echo "test-installer-e2e requires a clean repository" >&2
	exit 1
fi

active_pid_file="$repo_root/.pi/tmp/installer-e2e-active.pid"
cleanup() {
	if [[ -s $active_pid_file ]]; then
		pid=$(<"$active_pid_file")
		kill "$pid" 2>/dev/null || true
		sleep 1
		kill -KILL "$pid" 2>/dev/null || true
		rm -f "$active_pid_file"
	fi
}
trap cleanup EXIT INT TERM

timeout --signal=TERM --kill-after=30s 45m \
	nix develop -c python tests/installer-e2e/run.py
