#!/usr/bin/env bash
set -euo pipefail

repo_dir="${PI_BOOT_RESUME_REPO:-$HOME/documents/nix-dotfiles}"
system_prompt_file="${PI_BOOT_RESUME_SYSTEM_PROMPT:-$repo_dir/.pi/boot-system.md}"
task_prompt_file="${PI_BOOT_RESUME_TASK_PROMPT:-$repo_dir/.pi/boot-task.md}"
legacy_prompt_file="${PI_BOOT_RESUME_PROMPT:-}"

cd "$repo_dir"

if [[ ${PI_BOOT_RESUME_TMUX:-1} != 0 && -z ${PI_BOOT_RESUME_IN_TMUX:-} && -z ${TMUX:-} ]]; then
	if command -v tmux >/dev/null 2>&1; then
		tmux_session="${PI_BOOT_RESUME_TMUX_SESSION:-default}"
		tmux_window="${PI_BOOT_RESUME_TMUX_WINDOW:-pi-boot-resume}"

		if ! tmux has-session -t "=$tmux_session" 2>/dev/null; then
			tmux new-session -d -s "$tmux_session" -c "$repo_dir"
		fi

		if tmux list-windows -t "=$tmux_session" -F '#{window_name}' | grep -Fxq "$tmux_window"; then
			tmux kill-window -t "=$tmux_session:$tmux_window" 2>/dev/null || true
		fi

		printf -v tmux_command 'PI_BOOT_RESUME_IN_TMUX=1 exec %q' "$0"
		tmux_target="$(tmux new-window -d -P -F '#{session_name}:#{window_index}' \
			-t "=$tmux_session:" \
			-n "$tmux_window" \
			-c "$repo_dir" \
			"$tmux_command")"
		tmux select-window -t "$tmux_target"
		exec tmux attach-session -t "=$tmux_session"
	fi
fi

prompt=""
if [[ -n $legacy_prompt_file && -s $legacy_prompt_file ]]; then
	prompt="$(cat "$legacy_prompt_file")"
else
	if [[ -s $system_prompt_file ]]; then
		prompt="$(cat "$system_prompt_file")"
	fi
	if [[ -s $task_prompt_file ]]; then
		if [[ -n $prompt ]]; then
			prompt+=$'\n---\n\n'
		fi
		prompt+="$(cat "$task_prompt_file")"
	fi
fi

if [[ -n $prompt ]]; then
	exec pi -c "$prompt"
fi

exec pi -c
