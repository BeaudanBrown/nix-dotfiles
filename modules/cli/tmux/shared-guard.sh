#!/usr/bin/env bash
# shellcheck disable=SC2154
# The caller supplies immutable raw_tmux, socket and shared_unit values.
set -euo pipefail
if ! "$raw_tmux" -N -S "$socket" display-message -p '#{pid}' >/dev/null 2>&1; then
	systemctl --user start "$shared_unit"
	for ((attempt = 0; attempt < 100; attempt++)); do
		"$raw_tmux" -N -S "$socket" display-message -p '#{pid}' >/dev/null 2>&1 && break
		sleep 0.05
	done
fi
pid=$("$raw_tmux" -N -S "$socket" display-message -p '#{pid}')
expected=$(systemctl --user show "$shared_unit" -p MainPID --value)
if [[ $pid != "$expected" || $pid == 0 ]] || ! grep -Fq "/$shared_unit" "/proc/$pid/cgroup"; then
	echo 'Relay update deferred: shared tmux has legacy ownership. Finish work and close the old server during an approved maintenance window; then start tmux-shared and pi-managed-session-rollout.' >&2
	exit 1
fi
