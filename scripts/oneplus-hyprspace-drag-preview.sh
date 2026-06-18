#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat <<'EOF'
Usage: oneplus-hyprspace-drag-preview [--dry-run] --from <x> <y> --to <x> <y> [--duration-ms <ms>] [--steps <n>] [--screenshot-label <label>]

Perform exactly one bounded preview drag gesture.
Coordinates are Hyprspace/Hyprland logical coordinates, matching oneplus-hyprspace-hitboxes output. This helper never loops, rebuilds, reboots, or commits.

When --screenshot-label is provided, the helper pauses at the target while the button is still down, captures one screenshot, then releases. This is intended to verify drag-ghost rendering.
EOF
}

is_uint() { [[ ${1:-} =~ ^[0-9]+$ ]]; }
require_uint() {
	local name="$1" value="$2"
	if ! is_uint "$value"; then
		echo "$name must be a non-negative integer: $value" >&2
		exit 2
	fi
}

move_pointer() {
	local x="$1" y="$2"
	if command -v hyprctl >/dev/null 2>&1 && [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
		hyprctl dispatch movecursor "$x" "$y" >/dev/null
	else
		ydotool mousemove --absolute -- "$x" "$y"
	fi
}

require_backend() {
	if ! command -v ydotool >/dev/null 2>&1; then
		echo "No input backend found: ydotool is unavailable." >&2
		exit 1
	fi
	local socket="${YDOTOOL_SOCKET:-${XDG_RUNTIME_DIR:-}/.ydotool_socket}"
	if [[ -n $socket && ! -S $socket ]]; then
		echo "ydotool socket is not available: $socket" >&2
		exit 1
	fi
}

dry_run=0
from_x="" from_y="" to_x="" to_y="" duration_ms=600 steps=16 screenshot_label=""

while [[ $# -gt 0 ]]; do
	case "$1" in
	-h | --help)
		usage
		exit 0
		;;
	--dry-run)
		dry_run=1
		shift
		;;
	--from)
		[[ $# -ge 3 ]] || {
			echo "--from requires x y" >&2
			exit 2
		}
		from_x="$2"
		from_y="$3"
		shift 3
		;;
	--to)
		[[ $# -ge 3 ]] || {
			echo "--to requires x y" >&2
			exit 2
		}
		to_x="$2"
		to_y="$3"
		shift 3
		;;
	--duration-ms)
		[[ $# -ge 2 ]] || {
			echo "--duration-ms requires a value" >&2
			exit 2
		}
		duration_ms="$2"
		shift 2
		;;
	--steps)
		[[ $# -ge 2 ]] || {
			echo "--steps requires a value" >&2
			exit 2
		}
		steps="$2"
		shift 2
		;;
	--screenshot-label)
		[[ $# -ge 2 ]] || {
			echo "--screenshot-label requires a value" >&2
			exit 2
		}
		screenshot_label="$2"
		shift 2
		;;
	*)
		echo "Unknown argument: $1" >&2
		usage >&2
		exit 2
		;;
	esac
done

[[ -n $from_x && -n $from_y && -n $to_x && -n $to_y ]] || {
	usage >&2
	exit 2
}
require_uint from_x "$from_x"
require_uint from_y "$from_y"
require_uint to_x "$to_x"
require_uint to_y "$to_y"
require_uint duration_ms "$duration_ms"
require_uint steps "$steps"
if [[ $steps -lt 1 ]]; then
	echo "--steps must be at least 1" >&2
	exit 2
fi

backend="oneplus-touch swipe"
if [[ -n $screenshot_label ]]; then
	backend="hyprctl movecursor + ydotool click + oneplus-screenshot"
fi
printf 'Hyprspace preview drag: from=(%s,%s) to=(%s,%s) duration_ms=%s steps=%s backend=%s dry_run=%s screenshot_label=%s\n' \
	"$from_x" "$from_y" "$to_x" "$to_y" "$duration_ms" "$steps" "$backend" "$dry_run" "${screenshot_label:-none}"

if [[ -z $screenshot_label ]]; then
	args=(swipe "$from_x" "$from_y" "$to_x" "$to_y" --duration-ms "$duration_ms" --steps "$steps")
	if [[ $dry_run -eq 1 ]]; then
		oneplus-touch --dry-run "${args[@]}"
	else
		oneplus-touch "${args[@]}"
	fi
	exit 0
fi

if [[ $dry_run -eq 1 ]]; then
	printf 'Would hold-drag (%s,%s) -> (%s,%s), screenshot label %s, then release\n' "$from_x" "$from_y" "$to_x" "$to_y" "$screenshot_label"
	exit 0
fi

require_backend
sleep_s="$(awk -v ms="$duration_ms" -v steps="$steps" 'BEGIN { printf "%.3f", (ms / 1000) / steps }')"
move_pointer "$from_x" "$from_y"
ydotool click 0x40
for ((i = 1; i <= steps; i++)); do
	x=$((from_x + ((to_x - from_x) * i / steps)))
	y=$((from_y + ((to_y - from_y) * i / steps)))
	move_pointer "$x" "$y"
	sleep "$sleep_s"
done
sleep 0.2
oneplus-screenshot --label "$screenshot_label"
ydotool click 0x80
printf 'Held, captured, and released preview drag (%s, %s) -> (%s, %s) over %sms using %s steps\n' "$from_x" "$from_y" "$to_x" "$to_y" "$duration_ms" "$steps"
