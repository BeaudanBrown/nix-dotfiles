#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat <<'EOF'
Usage: oneplus-key [--dry-run] <key-name>
       oneplus-key [--dry-run] text <text>

Send one bounded key/text input action.

Key names: enter escape tab backspace space up down left right back home volume-up volume-down power
Back/home/power semantics depend on the running compositor and input stack.
This helper never loops, commits, rebuilds, or reboots.
EOF
}

require_ydotool() {
	if ! command -v ydotool >/dev/null 2>&1; then
		echo "No key backend found: ydotool is unavailable." >&2
		echo "Run through the flake app or add ydotool to the OnePlus environment." >&2
		exit 1
	fi
	local socket="${YDOTOOL_SOCKET:-${XDG_RUNTIME_DIR:-}/.ydotool_socket}"
	if [[ -n $socket && ! -S $socket ]]; then
		echo "ydotool socket is not available: $socket" >&2
		echo "Start/configure ydotoold with uinput access before sending key events." >&2
		exit 1
	fi
}

key_code() {
	case "$1" in
	enter) printf '28' ;;
	escape | esc) printf '1' ;;
	tab) printf '15' ;;
	backspace) printf '14' ;;
	space) printf '57' ;;
	up) printf '103' ;;
	down) printf '108' ;;
	left) printf '105' ;;
	right) printf '106' ;;
	back) printf '158' ;;        # KEY_BACK
	home) printf '102' ;;        # KEY_HOME
	volume-up) printf '115' ;;   # KEY_VOLUMEUP
	volume-down) printf '114' ;; # KEY_VOLUMEDOWN
	power) printf '116' ;;       # KEY_POWER
	*) return 1 ;;
	esac
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
text)
	shift
	[[ $# -ge 1 ]] || {
		echo "text requires an argument" >&2
		usage >&2
		exit 2
	}
	text="$*"
	if [[ $dry_run -eq 1 ]]; then
		printf 'Would type text (%s chars) using wtype if available, otherwise ydotool\n' "${#text}"
		exit 0
	fi
	if command -v wtype >/dev/null 2>&1 && [[ -n ${WAYLAND_DISPLAY:-} ]]; then
		wtype "$text"
		printf 'Typed text (%s chars) using wtype\n' "${#text}"
	else
		require_ydotool
		ydotool type "$text"
		printf 'Typed text (%s chars) using ydotool\n' "${#text}"
	fi
	;;
'')
	usage >&2
	exit 2
	;;
*)
	name="$1"
	if ! code="$(key_code "$name")"; then
		echo "Unknown key name: $name" >&2
		usage >&2
		exit 2
	fi
	if [[ $dry_run -eq 1 ]]; then
		printf 'Would press key %s using Linux input code %s via ydotool\n' "$name" "$code"
		exit 0
	fi
	require_ydotool
	ydotool key "${code}:1" "${code}:0"
	printf 'Pressed key %s using Linux input code %s via ydotool\n' "$name" "$code"
	;;
esac
