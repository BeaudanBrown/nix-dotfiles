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

: >"$log_file"

echo "Writing OnePlus audio debug output to: $log_file"

run "kernel audio messages from dmesg" \
	sudo dmesg

run "kernel audio messages from journalctl" \
	sudo journalctl -b -k --no-pager

{
	echo
	echo "===== filtered kernel audio messages ====="
	sudo dmesg | grep -Ei 'snd|alsa|audio|wsa|wcd|slim|sound|q6|apr|glink|adsp|codec|asoc|qcom' | tail -250 || true

	echo
	echo "===== filtered journal kernel audio messages ====="
	sudo journalctl -b -k --no-pager | grep -Ei 'snd|alsa|audio|wsa|wcd|slim|sound|q6|apr|glink|adsp|codec|asoc|qcom' | tail -250 || true

	echo
	echo "===== ASoC cards ====="
	sudo cat /sys/kernel/debug/asoc/cards 2>/dev/null || true

	echo
	echo "===== ASoC debug files ====="
	sudo find /sys/kernel/debug/asoc -maxdepth 3 \( -type f -name dapm -o -type f -name codec_reg \) 2>/dev/null | head -50 || true
} | tee -a "$log_file"

echo "Done. Output saved to: $log_file"
