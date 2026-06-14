#!/usr/bin/env bash
set -euo pipefail

repo_dir="${PI_BOOT_RESUME_REPO:-$HOME/documents/nix-dotfiles}"
system_prompt_file="${PI_BOOT_RESUME_SYSTEM_PROMPT:-$repo_dir/.pi/boot-system.md}"
task_prompt_file="${PI_BOOT_RESUME_TASK_PROMPT:-$repo_dir/.pi/boot-task.md}"
legacy_prompt_file="${PI_BOOT_RESUME_PROMPT:-}"

cd "$repo_dir"

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
