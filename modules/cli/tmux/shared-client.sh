#!/usr/bin/env bash
# shellcheck disable=SC2154
# Explicit socket clients keep stock tmux semantics (e.g. disposable tests).
# Inspect only global options, never arguments to a tmux command.
while getopts ':2CDhlNuVvc:f:L:S:T:' opt; do
	case "$opt" in
	S | L | V) exec "$raw_tmux" "$@" ;;
	*) : ;; # Pass other options (and their validation) through to tmux.
	esac
done
# Inside tmux, let tmux resolve its inherited socket, including test servers.
if [[ -z ${TMUX:-} ]]; then
	export TMUX_TMPDIR="${XDG_RUNTIME_DIR:?Shared tmux requires XDG_RUNTIME_DIR}"
fi
exec "$raw_tmux" -N "$@"
