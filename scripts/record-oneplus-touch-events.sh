#!/usr/bin/env bash
set -euo pipefail

seconds="${1:-30}"
out="${2:-/tmp/oneplus-touch-events-$(date +%Y%m%d-%H%M%S)}"
start_iso="$(date -Is)"
mkdir -p "$out"

have() { command -v "$1" >/dev/null 2>&1; }
run_nix() {
	local pkg="$1"
	shift
	if have "$1"; then
		"$@"
	else
		nix shell "nixpkgs#$pkg" -c "$@"
	fi
}

sudo -v

cat >"$out/README.txt" <<EOF
OnePlus touch/scroll event capture
Started: ${start_iso}
Duration: ${seconds}s

While this script is recording, try:
1. A one-finger swipe in Ghostty/tmux.
2. A one-finger swipe in plain Ghostty if available.
3. A two-finger swipe if possible.
4. Volume up once near the end, as a sanity check that input capture works.

Logs:
- libinput.log: compositor-level input events (TOUCH_*, POINTER_AXIS, GESTURE_*)
- evtest-event*.log: raw kernel evdev events per /dev/input/event*
- terminal-bytes.hex: bytes delivered to this terminal stdin, useful for mouse-wheel escape sequences
- wev.log: Wayland events if a wev window could be opened; swipe inside that window too
- oneplus-niri-gestures.log: lisgd service events; useful to prove the raw touchscreen swipe reached the global gesture layer
EOF

{
	echo "=== env"
	env | sort | grep -E '^(WAYLAND_DISPLAY|XDG_RUNTIME_DIR|DISPLAY|NIRI_SOCKET|TERM|TMUX|SHELL)=' || true
	echo
	echo "=== input devices"
	sed -n '1,260p' /proc/bus/input/devices
	echo
	echo "=== /dev/input"
	ls -l /dev/input /dev/input/by-path 2>/dev/null || true
} >"$out/context.txt" 2>&1

# Start background captures before countdown so they are definitely active.
(
	if have libinput; then
		sudo libinput debug-events
	else
		sudo nix shell nixpkgs#libinput -c libinput debug-events
	fi
) >"$out/libinput.log" 2>&1 &
libinput_pid=$!

for e in /dev/input/event*; do
	name="$(basename "$e")"
	(
		if have evtest; then
			sudo evtest "$e"
		else
			sudo nix shell nixpkgs#evtest -c evtest "$e"
		fi
	) >"$out/evtest-$name.log" 2>&1 &
done

# Capture terminal input bytes. If Ghostty/tmux turns touch swipes into mouse escape
# sequences, they should show up here. Keep it best-effort: reading stdin can fight
# the shell, so do it only while this script owns the terminal.
(
	oldstty="$(stty -g 2>/dev/null || true)"
	trap 'test -n "${oldstty:-}" && stty "$oldstty" 2>/dev/null || true' EXIT
	stty raw -echo min 0 time 1 2>/dev/null || true
	timeout "$seconds" dd bs=1 status=none 2>/dev/null | od -An -tx1 -v
) >"$out/terminal-bytes.hex" 2>&1 &
terminal_pid=$!

# If GUI env is available, open wev. Swipe inside the wev window too.
if [[ -n ${WAYLAND_DISPLAY:-} && -n ${XDG_RUNTIME_DIR:-} ]]; then
	(
		run_nix wev wev
	) >"$out/wev.log" 2>&1 &
	wev_pid=$!
else
	wev_pid=""
	echo "No WAYLAND_DISPLAY/XDG_RUNTIME_DIR; skipped wev" >"$out/wev.log"
fi

for n in 3 2 1; do
	printf '\rRecording starts in %s... ' "$n"
	sleep 1
done
printf '\rRecording for %ss. Swipe now. Logs: %s\n' "$seconds" "$out"

sleep "$seconds"

journalctl --unit=oneplus-niri-gestures --since "$start_iso" --no-pager >"$out/oneplus-niri-gestures.log" 2>&1 ||
	echo "Could not read oneplus-niri-gestures journal" >"$out/oneplus-niri-gestures.log"

kill "$libinput_pid" "$terminal_pid" ${wev_pid:-} 2>/dev/null || true
pkill -P $$ evtest 2>/dev/null || true
wait 2>/dev/null || true

{
	echo "Summary for $out"
	echo
	echo "== libinput runtime events =="
	grep -E 'TOUCH_|POINTER_|GESTURE_|KEY_|TABLET_|SWITCH_' "$out/libinput.log" || echo "none"
	echo
	echo "== evtest runtime events =="
	for f in "$out"/evtest-event*.log; do
		echo "-- $(basename "$f")"
		grep -E '^Event: time' "$f" | head -200 || echo "none"
	done
	echo
	echo "== terminal input bytes =="
	if grep -q '[0-9a-f][0-9a-f]' "$out/terminal-bytes.hex"; then
		cat "$out/terminal-bytes.hex"
	else
		echo "none"
	fi
	echo
	echo "== wev notable events =="
	grep -E 'pointer|touch|axis|gesture|keyboard|button' "$out/wev.log" || echo "none"
	echo
	echo "== oneplus lisgd gesture events =="
	grep -E 'Swipe distance|Execute|\[swipe\]' "$out/oneplus-niri-gestures.log" || echo "none"
} | tee "$out/summary.txt"

printf '\nDone. Send me this summary path or paste it:\n  %s/summary.txt\nFull logs are in:\n  %s\n' "$out" "$out"
