#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat <<'EOF'
Usage: oneplus-screenshot [--label <name>] [--out <path>] [--dir <dir>] [--dry-run]

Capture the current OnePlus/Wayland UI to a PNG and print a Pi read hint.
Writes to /tmp/oneplus-agent-ui by default. Performs one bounded action only.
EOF
}

label="current-ui"
out=""
out_dir="/tmp/oneplus-agent-ui"
dry_run=0

while [[ $# -gt 0 ]]; do
	case "$1" in
	--label)
		[[ $# -ge 2 ]] || {
			echo "--label requires a value" >&2
			exit 2
		}
		label="$2"
		shift 2
		;;
	--out)
		[[ $# -ge 2 ]] || {
			echo "--out requires a path" >&2
			exit 2
		}
		out="$2"
		shift 2
		;;
	--dir)
		[[ $# -ge 2 ]] || {
			echo "--dir requires a path" >&2
			exit 2
		}
		out_dir="$2"
		shift 2
		;;
	--dry-run)
		dry_run=1
		shift
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		echo "Unknown argument: $1" >&2
		usage >&2
		exit 2
		;;
	esac
done

if ! command -v grim >/dev/null 2>&1; then
	echo "No screenshot backend found: grim is unavailable." >&2
	echo "Run through the flake app or add grim to the OnePlus graphical environment." >&2
	exit 1
fi

if [[ -z ${WAYLAND_DISPLAY:-} ]]; then
	echo "WAYLAND_DISPLAY is not set; cannot capture a Wayland screenshot." >&2
	exit 1
fi

safe_label="$(printf '%s' "$label" | tr -c '[:alnum:]_.-' '-')"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"

if [[ -z $out ]]; then
	mkdir -p "$out_dir"
	out="$out_dir/${timestamp}-${safe_label}.png"
else
	mkdir -p "$(dirname "$out")"
fi

if [[ $dry_run -eq 1 ]]; then
	printf 'Would capture screenshot: %s\n' "$out"
	printf 'Backend: grim\n'
	printf 'Agent read hint: read %s\n' "$out"
	exit 0
fi

grim "$out"

if [[ ! -s $out ]]; then
	echo "Screenshot backend completed but did not create a non-empty file: $out" >&2
	exit 1
fi

printf 'Screenshot: %s\n' "$out"
printf 'Backend: grim\n'
if command -v identify >/dev/null 2>&1; then
	identify -format 'Dimensions: %wx%h\n' "$out" || true
fi
printf 'Agent read hint: read %s\n' "$out"
