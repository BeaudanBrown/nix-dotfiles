#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat <<'EOF'
Usage: oneplus-touch [--dry-run] tap <x> <y>
       oneplus-touch [--dry-run] swipe <x1> <y1> <x2> <y2> [--duration-ms <ms>] [--steps <n>]

Perform one bounded pointer interaction through ydotool.
Coordinates are Hyprland logical absolute coordinates when hyprctl is available, otherwise backend absolute coordinates. This helper never loops, commits, rebuilds, or reboots.
EOF
}

is_uint() {
	[[ ${1:-} =~ ^[0-9]+$ ]]
}

require_uint() {
	local name="$1"
	local value="$2"
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
		echo "Run through the flake app or add ydotool to the OnePlus environment." >&2
		exit 1
	fi
	local socket="${YDOTOOL_SOCKET:-${XDG_RUNTIME_DIR:-}/.ydotool_socket}"
	if [[ -n $socket && ! -S $socket ]]; then
		echo "ydotool socket is not available: $socket" >&2
		echo "Start/configure ydotoold with uinput access before sending input events." >&2
		exit 1
	fi
}

dry_run=0
if [[ ${1:-} == "--dry-run" ]]; then
	dry_run=1
	shift
fi

case "${1:-}" in
-h | --help)
	usage
	exit 0
	;;
tap)
	[[ $# -eq 3 ]] || {
		usage >&2
		exit 2
	}
	x="$2"
	y="$3"
	require_uint x "$x"
	require_uint y "$y"
	if [[ $dry_run -eq 1 ]]; then
		printf 'Would tap absolute coordinate (%s, %s) using ydotool\n' "$x" "$y"
		exit 0
	fi
	require_backend
	move_pointer "$x" "$y"
	ydotool click 0xC0
	printf 'Tapped absolute coordinate (%s, %s) using ydotool\n' "$x" "$y"
	;;
swipe)
	shift
	[[ $# -ge 4 ]] || {
		usage >&2
		exit 2
	}
	x1="$1"
	y1="$2"
	x2="$3"
	y2="$4"
	shift 4
	duration_ms=400
	steps=12
	while [[ $# -gt 0 ]]; do
		case "$1" in
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
		*)
			echo "Unknown swipe argument: $1" >&2
			usage >&2
			exit 2
			;;
		esac
	done
	require_uint x1 "$x1"
	require_uint y1 "$y1"
	require_uint x2 "$x2"
	require_uint y2 "$y2"
	require_uint duration_ms "$duration_ms"
	require_uint steps "$steps"
	if [[ $steps -lt 1 ]]; then
		echo "--steps must be at least 1" >&2
		exit 2
	fi
	if [[ $dry_run -eq 1 ]]; then
		printf 'Would swipe (%s, %s) -> (%s, %s) over %sms using %s steps with ydotool\n' "$x1" "$y1" "$x2" "$y2" "$duration_ms" "$steps"
		exit 0
	fi
	require_backend
	sleep_s="$(awk -v ms="$duration_ms" -v steps="$steps" 'BEGIN { printf "%.3f", (ms / 1000) / steps }')"
	move_pointer "$x1" "$y1"
	ydotool click 0x40
	for ((i = 1; i <= steps; i++)); do
		x=$((x1 + ((x2 - x1) * i / steps)))
		y=$((y1 + ((y2 - y1) * i / steps)))
		move_pointer "$x" "$y"
		sleep "$sleep_s"
	done
	ydotool click 0x80
	printf 'Swiped (%s, %s) -> (%s, %s) over %sms using %s steps with ydotool\n' "$x1" "$y1" "$x2" "$y2" "$duration_ms" "$steps"
	;;
*)
	usage >&2
	exit 2
	;;
esac
