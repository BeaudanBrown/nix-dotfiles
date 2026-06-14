#!/usr/bin/env bash
set -euo pipefail

log_file="${1:-oneplus-audio-debug.log}"

run() {
	local title="$1"
	shift

	{
		echo
		echo "===== ${title} ====="
		echo "COMMAND: $*"
	} | tee -a "$log_file"

	"$@" 2>&1 | tee -a "$log_file" || true
}

run_sh() {
	local title="$1"
	shift

	{
		echo
		echo "===== ${title} ====="
		echo "COMMAND: $*"
	} | tee -a "$log_file"

	sh -c "$*" 2>&1 | tee -a "$log_file" || true
}

have() {
	command -v "$1" >/dev/null 2>&1
}

: >"$log_file"

echo "Writing OnePlus audio debug output to: $log_file"

run "PipeWire status" wpctl status

if have systemctl; then
	run "WirePlumber environment" systemctl --user show wireplumber -p Environment --value
fi

if have journalctl; then
	run "PipeWire and WirePlumber user logs" journalctl --user -b --no-pager -u pipewire -u wireplumber
	run "kernel messages from journalctl" journalctl -b -k --no-pager
fi

if have dmesg; then
	run "kernel messages from dmesg" dmesg
fi

run "ALSA PCM devices" cat /proc/asound/pcm
run "ALSA cards" cat /proc/asound/cards

run_sh "filtered kernel audio messages" \
	"{ dmesg 2>/dev/null || journalctl -b -k --no-pager 2>/dev/null || true; } | grep -Ei 'snd|alsa|audio|wsa|wcd|slim|sound|q6|apr|glink|adsp|codec|asoc|qcom|tfa' | tail -250"

run_sh "filtered PipeWire/WirePlumber messages" \
	"journalctl --user -b --no-pager -u pipewire -u wireplumber 2>/dev/null | grep -Ei 'alsa|ucm|profile|pro|dummy|invalid|speaker|sink|source|wireplumber|pipewire' | tail -250"

if have pw-dump; then
	run_sh "PipeWire ALSA object summary" \
		"pw-dump 2>/dev/null | grep -Ei 'alsa_card.platform-sound|O6T|OnePlus6T|HiFi|Speaker|pro-audio|profile|ucm|alsa_output' | head -300"
fi

if have alsaucm; then
	run "UCM dump for O6T" alsaucm -c O6T dump text
elif have nix; then
	run_sh "UCM dump for O6T via nix shell" \
		"nix shell nixpkgs#alsa-utils -c alsaucm -c O6T dump text"
fi

if have aplay; then
	run "aplay devices" aplay -l
elif have nix; then
	run_sh "aplay devices via nix shell" \
		"nix shell nixpkgs#alsa-utils -c aplay -l"
fi

if [[ -r /sys/kernel/debug/asoc/cards ]]; then
	run "ASoC cards" cat /sys/kernel/debug/asoc/cards
else
	{
		echo
		echo "===== ASoC cards ====="
		echo "Skipped: /sys/kernel/debug/asoc/cards is not readable without sudo."
	} | tee -a "$log_file"
fi

echo "Done. Output saved to: $log_file"
