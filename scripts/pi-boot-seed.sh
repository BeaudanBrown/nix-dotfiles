#!/usr/bin/env bash
set -euo pipefail

repo_dir="${PI_BOOT_RESUME_REPO:-$HOME/documents/nix-dotfiles}"
task_prompt_file="${PI_BOOT_RESUME_TASK_PROMPT:-$repo_dir/.pi/boot-task.md}"

mkdir -p "$(dirname "$task_prompt_file")"

if [[ $# -gt 0 ]]; then
	printf '%s\n' "$*" >"$task_prompt_file"
else
	${EDITOR:-vi} "$task_prompt_file"
fi

printf 'Updated %s\n' "$task_prompt_file"
