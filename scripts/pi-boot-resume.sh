#!/usr/bin/env bash
set -euo pipefail

repo_dir="${PI_BOOT_RESUME_REPO:-$HOME/documents/nix-dotfiles}"
prompt_file="${PI_BOOT_RESUME_PROMPT:-$repo_dir/.pi/boot-prompt.md}"

cd "$repo_dir"

if [[ -s $prompt_file ]]; then
	exec pi -c "$(cat "$prompt_file")"
fi

exec pi -c
