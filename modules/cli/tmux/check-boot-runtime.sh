#!/usr/bin/env bash
# Run after activation. Uses only disposable sockets, never the live server.
set -euo pipefail
launcher=${1:-$(command -v tmux_project)}
package=$(dirname "$(dirname "$(readlink -f "$launcher")")")
tmux="$package/libexec/tmux"
[[ -x $tmux ]] || {
	echo "Activate the new tmux_project package first" >&2
	exit 1
}
config=${XDG_CONFIG_HOME:-$HOME/.config}/tmux/tmux.conf
[[ -r $config ]]
root=$(mktemp -d)
cleanup() {
	for mode in relay interactive; do
		"$tmux" -S "$root/$mode/socket" kill-server 2>/dev/null || true
	done
	rm -rf "$root"
}
trap cleanup EXIT
for mode in relay interactive; do
	mkdir -m 700 "$root/$mode"
	socket="$root/$mode/socket"
	# No inherited TMUX, login PATH, or XDG_CONFIG_HOME in the boot case.
	environment=(env -i "HOME=$HOME" "USER=${USER:-$(id -un)}" TERM=xterm-256color
	"XDG_RUNTIME_DIR=$root/$mode" "TMUX_TMPDIR=$root/$mode" PATH=/nonexistent)
	if [[ $mode == interactive ]]; then
		environment+=("PATH=$PATH" "XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-$HOME/.config}")
	fi
	"${environment[@]}" "$tmux" -S "$socket" new-session -d -s runtime-probe 'sleep 120'
	t() { "${environment[@]}" "$tmux" -S "$socket" "$@"; }
	[[ $(t show-options -gv prefix) == C-Space ]]
	[[ $(t show-options -gv status-position) == top ]]
	[[ -n $(t show-options -gqv @catppuccin_cpu_color) ]]
	t list-keys >"$root/all-keys"
	grep -q extrakto "$root/all-keys"
	t list-keys -T copy-mode-vi >"$root/keys"
	grep -q 'yank\|tmux-copy-system' "$root/keys"
	copy=$(t show-options -gv copy-command)
	[[ $copy == /nix/store/*/bin/tmux-copy-system && -x $copy ]]
	# Exercise commands from the SERVER environment, not this test's shell.
	t run-shell "command -v bash tmux tmux_project > '$root/commands'"
	grep -Fx "$package/bin/tmux_project" "$root/commands"
	[[ $(wc -l <"$root/commands") -eq 3 ]]
	output=$(t source-file "$config" 2>&1)
	[[ -z $output ]] || {
		printf '%s\n' "$output" >&2
		exit 1
	}
	t run-shell "tmux_project note-root-focus '' runtime-probe; printf '%s' \$? > '$root/hook-status'"
	[[ $(<"$root/hook-status") == 0 ]]
	t run-shell "printf runtime-copy-probe | '$copy'; printf '%s' \$? > '$root/copy-status'"
	[[ $(<"$root/copy-status") == 0 ]]
	[[ $(t show-buffer) == runtime-copy-probe ]]
	# Trigger the configured hook, not merely its underlying command.
	t new-session -d -s closed-probe 'sleep 120'
	t set-option -g @project_root_mru $'closed-probe\truntime-probe'
	t kill-session -t '=closed-probe'
	for ((attempt = 0; attempt < 50; attempt++)); do
		[[ $(t show-options -gqv @project_root_mru) == runtime-probe ]] && break
		sleep 0.1
	done
	[[ $(t show-options -gqv @project_root_mru) == runtime-probe ]]
	echo "$mode-first config, plugins, command resolution, hooks, copy, and reload: PASS"
done
