#!/usr/bin/env bash
set -euo pipefail

lines=2000
if [[ ${1:-} == "--lines" ]]; then
	[[ $# -ge 2 ]] || {
		echo "--lines requires a value" >&2
		exit 2
	}
	lines="$2"
	shift 2
fi
if [[ $# -gt 0 ]]; then
	echo "Usage: oneplus-hyprspace-hitboxes [--lines <n>]" >&2
	exit 2
fi

pattern='Hyprspace (preview|workspace) hitbox|Hyprspace preview drag'
found=0

if [[ -f /tmp/hyprspace-hitboxes.log ]]; then
	if tail -n "$lines" /tmp/hyprspace-hitboxes.log | rg "$pattern"; then
		found=1
	fi
fi

if command -v journalctl >/dev/null 2>&1; then
	if journalctl --user -b --no-pager -n "$lines" 2>/dev/null | rg "$pattern"; then
		found=1
	fi
fi

log_dir="${XDG_RUNTIME_DIR:-}/hypr"
if [[ -d $log_dir ]]; then
	while IFS= read -r -d '' log; do
		if tail -n "$lines" "$log" 2>/dev/null | rg "$pattern"; then
			found=1
		fi
	done < <(find "$log_dir" -type f \( -name '*.log' -o -name 'hyprland.log' \) -print0 2>/dev/null)
fi

if [[ $found -eq 0 ]]; then
	echo "No recent Hyprspace hitbox logs found. Ensure plugin:overview:debugHitboxes = 1 and open overview once." >&2
	exit 1
fi
