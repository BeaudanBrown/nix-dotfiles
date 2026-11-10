#!/usr/bin/env bash
# shellcheck disable=SC2154
# Sourced by the packaged tmux entrypoint. Custom sockets remain disposable.
set -euo pipefail
if [[ -n ${TMUX:-} ]]; then
	exec "$raw_tmux" "$@"
fi
for argument in "$@"; do
	case "$argument" in
	-S | -S* | -L | -L* | -V) exec "$raw_tmux" "$@" ;;
	esac
done
: "${XDG_RUNTIME_DIR:?Shared tmux requires XDG_RUNTIME_DIR}"
export TMUX_TMPDIR="$XDG_RUNTIME_DIR"
socket="$XDG_RUNTIME_DIR/tmux-$(id -u)/default"
# Explicit read-only probes must not create/start a server as a side effect.
for argument in "$@"; do
	if [[ $argument == -N ]]; then
		exec "$raw_tmux" -N -S "$socket" "$@"
	fi
done
# Connect to existing servers without replacing them. Server lifetime is
# independent of the optional bridge and ordinary Pi processes.
if ! "$raw_tmux" -N -S "$socket" display-message -p '#{pid}' >/dev/null 2>&1; then
	systemctl --user start tmux-shared.service
	ready=false
	for ((attempt = 0; attempt < 100; attempt++)); do
		if "$raw_tmux" -N -S "$socket" display-message -p '#{pid}' >/dev/null 2>&1; then
			ready=true
			break
		fi
		sleep 0.05
	done
	if [[ $ready != true ]]; then
		echo 'Shared tmux failed to become ready; refusing unmanaged server creation' >&2
		exit 1
	fi
fi
# -N forbids this client from creating a server if it dies between the check
# and exec. Only the independently owned unit is permitted to create it.
exec "$raw_tmux" -N -S "$socket" "$@"
