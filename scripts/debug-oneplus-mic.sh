#!/usr/bin/env bash
set -euo pipefail

card="${ONEPLUS_AUDIO_CARD:-O6T}"
outdir="${1:-/tmp/oneplus-mic-debug-$(date +%s)}"
sudo_cmd="${SUDO:-/run/wrappers/bin/sudo}"
mkdir -p "$outdir"
log_file="$outdir/summary.txt"

log() {
	printf '%s\n' "$*" | tee -a "$log_file"
}

run() {
	local title="$1"
	shift
	{
		echo
		echo "===== $title ====="
		echo "COMMAND: $*"
	} | tee -a "$log_file"
	"$@" 2>&1 | tee -a "$log_file" || true
}

run_sh() {
	local title="$1"
	shift
	{
		echo
		echo "===== $title ====="
		echo "COMMAND: $*"
	} | tee -a "$log_file"
	bash -c "$*" 2>&1 | tee -a "$log_file" || true
}

have() {
	command -v "$1" >/dev/null 2>&1
}

sox_stat() {
	local wav="$1"
	if have sox; then
		sox "$wav" -n stat 2>&1
	elif have nix; then
		nix shell nixpkgs#sox -c sox "$wav" -n stat 2>&1
	else
		echo "sox unavailable"
	fi
}

cset() {
	amixer -c "$card" cset name="$1" "$2" >/dev/null 2>&1 || true
}

reset_capture_routes() {
	local mm src a s ctrl
	for mm in 1 2 3 4 5 6; do
		for src in \
			SLIMBUS_0_TX SLIMBUS_1_TX SLIMBUS_2_TX SLIMBUS_3_TX SLIMBUS_4_TX SLIMBUS_5_TX SLIMBUS_6_TX \
			TX_CODEC_DMA_TX_0 TX_CODEC_DMA_TX_1 TX_CODEC_DMA_TX_2 TX_CODEC_DMA_TX_3 TX_CODEC_DMA_TX_4 TX_CODEC_DMA_TX_5 \
			VA_CODEC_DMA_TX_0 VA_CODEC_DMA_TX_1 VA_CODEC_DMA_TX_2 \
			WSA_CODEC_DMA_TX_0 WSA_CODEC_DMA_TX_1 WSA_CODEC_DMA_TX_2; do
			cset "MultiMedia${mm} Mixer $src" 0
		done
	done
	for ctrl in \
		"VoiceMMode1 Capture Mixer SLIMBUS_0_TX" \
		"CS-Voice Capture Mixer SLIMBUS_0_TX" \
		"Headset Mic Switch"; do
		cset "$ctrl" 0
	done
	for a in 1 2 3; do
		for s in 0 1 2 3 4 5 6 7 8; do
			cset "AIF${a}_CAP Mixer SLIM TX$s" 0
		done
	done
}

setup_slimbus0_capture() {
	reset_capture_routes
	cset "MultiMedia2 Mixer SLIMBUS_0_TX" 1
	cset "AIF1_CAP Mixer SLIM TX0" 1
	cset "CDC_IF TX0 MUX" DEC0
	cset "ADC MUX0" AMIC
	cset "DEC0 Volume" 110
}

record_case() {
	local name="$1"
	local adc="$2"
	local extra="${3:-}"
	local before_lines wav err dmesg_delta code stat max rms samples adc_num

	setup_slimbus0_capture
	if [[ -n $extra ]]; then
		eval "$extra"
	fi
	cset "AMIC MUX0" "$adc"
	adc_num="${adc#ADC}"
	cset "ADC${adc_num} Volume" 20

	before_lines="$($sudo_cmd dmesg | wc -l)"
	wav="$outdir/$name.wav"
	err="$outdir/$name.err"
	dmesg_delta="$outdir/$name.dmesg"

	set +e
	timeout 5 arecord -q -D "hw:$card,1" -f S16_LE -r 48000 -c 1 -d 3 "$wav" 2>"$err"
	code=$?
	set -e

	$sudo_cmd dmesg | tail -n +$((before_lines + 1)) >"$dmesg_delta" || true

	if [[ $code -eq 0 ]]; then
		stat="$(sox_stat "$wav")"
		printf '%s\n' "$stat" >"$outdir/$name.sox-stat"
		max="$(printf '%s\n' "$stat" | awk '/Maximum amplitude/ {print $3}')"
		rms="$(printf '%s\n' "$stat" | awk '/RMS     amplitude/ {print $3}')"
		samples="$(printf '%s\n' "$stat" | awk '/Samples read/ {print $3}')"
		log "$name adc=$adc code=0 samples=${samples:-unknown} max=${max:-unknown} rms=${rms:-unknown} dmesg_lines=$(wc -l <"$dmesg_delta") wav=$wav"
	else
		log "$name adc=$adc code=$code err=$(tr '\n' ' ' <"$err") dmesg_lines=$(wc -l <"$dmesg_delta")"
	fi

	grep -Ei 'q6|afe|asm|slim|wcd|adc|mic|error|fail' "$dmesg_delta" | tee -a "$log_file" || true
}

capture_dapm_snapshot() {
	local name="$1"
	local dest="$outdir/$name.dapm"
	if $sudo_cmd test -d "/sys/kernel/debug/asoc/OnePlus 6T"; then
		$sudo_cmd grep -RHiE ': On|AMIC|MIC BIAS|ADC|CDC_IF TX|SLIM TX|AIF[123]|MultiMedia2|Headset Mic|Int Mic' \
			"/sys/kernel/debug/asoc/OnePlus 6T" 2>/dev/null | tee "$dest" >/dev/null || true
		log "DAPM snapshot saved: $dest"
	else
		log "DAPM snapshot skipped: ASoC debugfs path not present"
	fi
}

run_regmap_diff() {
	local reg before active pid
	reg="$($sudo_cmd sh -c 'test -r /sys/kernel/debug/regmap/217:250:1:0/registers && printf %s /sys/kernel/debug/regmap/217:250:1:0/registers' || true)"
	if [[ -z $reg ]]; then
		log "WCD934x regmap not found; available regmap register files:"
		# shellcheck disable=SC2016
		$sudo_cmd sh -c 'for f in /sys/kernel/debug/regmap/*/registers; do test -e "$f" && printf "%s\n" "$f"; done' | tee -a "$log_file" || true
		return 0
	fi

	before="$outdir/wcd934x-before.registers"
	active="$outdir/wcd934x-active.registers"
	setup_slimbus0_capture
	cset "AMIC MUX0" ADC1
	cset "ADC1 Volume" 20
	$sudo_cmd cat "$reg" | tee "$before" >/dev/null
	arecord -q -D "hw:$card,1" -f S16_LE -r 48000 -c 1 -d 8 "$outdir/regmap-amic1.wav" &
	pid=$!
	sleep 1
	$sudo_cmd cat "$reg" | tee "$active" >/dev/null
	capture_dapm_snapshot "regmap-amic1-active"
	wait "$pid" || true
	diff -u "$before" "$active" >"$outdir/wcd934x-regmap.diff" || true
	log "WCD934x regmap diff saved: $outdir/wcd934x-regmap.diff"
}

record_hw_pcm_current() {
	local name="$1"
	local dev="$2"
	local channels="${3:-1}"
	local seconds="${4:-2}"
	local before_lines wav err dmesg_delta code stat max rms samples

	before_lines="$($sudo_cmd dmesg | wc -l)"
	wav="$outdir/$name.wav"
	err="$outdir/$name.err"
	dmesg_delta="$outdir/$name.dmesg"

	set +e
	timeout $((seconds + 3)) arecord -q -D "hw:$card,$dev" -f S16_LE -r 48000 -c "$channels" -d "$seconds" "$wav" 2>"$err"
	code=$?
	set -e

	$sudo_cmd dmesg | tail -n +$((before_lines + 1)) >"$dmesg_delta" || true

	if [[ $code -eq 0 ]]; then
		stat="$(sox_stat "$wav")"
		printf '%s\n' "$stat" >"$outdir/$name.sox-stat"
		max="$(printf '%s\n' "$stat" | awk '/Maximum amplitude/ {print $3}')"
		rms="$(printf '%s\n' "$stat" | awk '/RMS     amplitude/ {print $3}')"
		samples="$(printf '%s\n' "$stat" | awk '/Samples read/ {print $3}')"
		log "$name dev=$dev channels=$channels code=0 samples=${samples:-unknown} max=${max:-unknown} rms=${rms:-unknown} dmesg_lines=$(wc -l <"$dmesg_delta") wav=$wav"
	else
		log "$name dev=$dev channels=$channels code=$code err=$(tr '\n' ' ' <"$err") dmesg_lines=$(wc -l <"$dmesg_delta")"
	fi
	grep -Ei 'q6|afe|asm|slim|wcd|adc|mic|error|fail' "$dmesg_delta" | tee -a "$log_file" || true
}

setup_amic_tx_path() {
	local tx="$1"
	local aif="$2"
	local adc="${3:-ADC1}"
	local adc_num

	cset "AIF${aif}_CAP Mixer SLIM TX$tx" 1
	cset "CDC_IF TX$tx MUX" "DEC$tx"
	cset "ADC MUX$tx" AMIC
	cset "AMIC MUX$tx" "$adc"
	adc_num="${adc#ADC}"
	cset "ADC${adc_num} Volume" 20
	cset "DEC$tx Volume" 110
}

run_multimedia_frontend_sweep() {
	local mm dev
	log ""
	log "===== MultiMedia frontend sweep: AMIC1 via SLIMBUS_0_TX ====="
	for mm in 1 2 3 4 5 6; do
		dev=$((mm - 1))
		reset_capture_routes
		cset "MultiMedia${mm} Mixer SLIMBUS_0_TX" 1
		setup_amic_tx_path 0 1 ADC1
		record_hw_pcm_current "mm${mm}_dev${dev}_slimbus0_amic1" "$dev" 1 2
	done
}

run_tx_slot_sweep() {
	local tx
	log ""
	log "===== TX slot sweep: MultiMedia2 + AIF1_CAP + AMIC1 ====="
	for tx in 0 1 2 3; do
		reset_capture_routes
		cset "MultiMedia2 Mixer SLIMBUS_0_TX" 1
		setup_amic_tx_path "$tx" 1 ADC1
		record_hw_pcm_current "mm2_aif1_tx${tx}_amic1" 1 1 2
	done
}

run_slimbus_link_sweep() {
	local link aif
	log ""
	log "===== SLIMBUS link sweep: MultiMedia2 + AIF{1,2,3}_CAP + AMIC1 ====="
	for link in 0 1 2; do
		aif=$((link + 1))
		reset_capture_routes
		cset "MultiMedia2 Mixer SLIMBUS_${link}_TX" 1
		setup_amic_tx_path "$link" "$aif" ADC1
		record_hw_pcm_current "mm2_slimbus${link}_aif${aif}_tx${link}_amic1" 1 1 2
	done
}

run_voice_frontend_sweep() {
	local rate before_lines wav err dmesg_delta code stat max rms samples name
	log ""
	log "===== VoiceMMode1 sweep: AMIC1 via SLIMBUS_0_TX ====="
	for rate in 8000 16000 32000 48000; do
		reset_capture_routes
		cset "VoiceMMode1 Capture Mixer SLIMBUS_0_TX" 1
		setup_amic_tx_path 0 1 ADC1
		name="voice_dev6_${rate}_amic1"
		before_lines="$($sudo_cmd dmesg | wc -l)"
		wav="$outdir/$name.wav"
		err="$outdir/$name.err"
		dmesg_delta="$outdir/$name.dmesg"
		set +e
		timeout 5 arecord -q -D "hw:$card,6" -f S16_LE -r "$rate" -c 1 -d 2 "$wav" 2>"$err"
		code=$?
		set -e
		$sudo_cmd dmesg | tail -n +$((before_lines + 1)) >"$dmesg_delta" || true
		if [[ $code -eq 0 ]]; then
			stat="$(sox_stat "$wav")"
			printf '%s\n' "$stat" >"$outdir/$name.sox-stat"
			max="$(printf '%s\n' "$stat" | awk '/Maximum amplitude/ {print $3}')"
			rms="$(printf '%s\n' "$stat" | awk '/RMS     amplitude/ {print $3}')"
			samples="$(printf '%s\n' "$stat" | awk '/Samples read/ {print $3}')"
			log "$name rate=$rate code=0 samples=${samples:-unknown} max=${max:-unknown} rms=${rms:-unknown} dmesg_lines=$(wc -l <"$dmesg_delta") wav=$wav"
		else
			log "$name rate=$rate code=$code err=$(tr '\n' ' ' <"$err") dmesg_lines=$(wc -l <"$dmesg_delta")"
		fi
		grep -Ei 'q6|afe|asm|slim|wcd|adc|mic|error|fail' "$dmesg_delta" | tee -a "$log_file" || true
	done
}

main() {
	: >"$log_file"
	log "OnePlus mic debug output: $outdir"
	log "boot=$(readlink -f /run/current-system 2>/dev/null || true)"
	log "card=$card"

	run "ALSA cards" cat /proc/asound/cards
	run "ALSA PCMs" cat /proc/asound/pcm
	run_sh "mic-related control list" "amixer -c '$card' controls | grep -Ei 'AMIC|ADC|DEC|CDC_IF TX|SLIM TX|MIC BIAS|Headset|MBHC|4_5|TX.*MUX|AIF.*CAP|MultiMedia.*TX|Voice.*TX'"
	{
		echo
		echo "===== selected control values ====="
	} | tee -a "$log_file"
	local selected_control
	for selected_control in \
		"AMIC4_5 SEL" \
		"AMIC MUX0" \
		"AMIC MUX1" \
		"AMIC MUX2" \
		"AMIC MUX3" \
		"ADC MUX0" \
		"CDC_IF TX0 MUX" \
		"Headset Mic Switch"; do
		{
			echo "=== $selected_control"
			amixer -c "$card" cget name="$selected_control" 2>/dev/null | sed -n '1,20p'
		} | tee -a "$log_file"
	done

	log ""
	log "===== AMIC sweep through MultiMedia2/SLIMBUS_0_TX/AIF1_CAP/TX0 ====="
	record_case amic1 ADC1
	record_case amic2 ADC2
	record_case amic2_headset ADC2 "cset 'Headset Mic Switch' 1"
	record_case amic3 ADC3
	record_case amic4_sel_amic4 ADC4 "cset 'AMIC4_5 SEL' AMIC4"
	record_case amic5_sel_amic5 ADC4 "cset 'AMIC4_5 SEL' AMIC5"

	run_multimedia_frontend_sweep
	run_tx_slot_sweep
	run_slimbus_link_sweep
	run_voice_frontend_sweep

	setup_slimbus0_capture
	cset "AMIC MUX0" ADC1
	cset "ADC1 Volume" 20
	arecord -q -D "hw:$card,1" -f S16_LE -r 48000 -c 1 -d 8 "$outdir/dapm-amic1.wav" &
	local pid=$!
	sleep 1
	capture_dapm_snapshot "amic1-active"
	wait "$pid" || true

	run_regmap_diff

	run_sh "hw:O6T,0 routed capture retry" "amixer -c '$card' cset name='MultiMedia1 Mixer SLIMBUS_0_TX' 1 >/dev/null 2>&1 || true; timeout 4 arecord -D hw:'$card',0 -f S16_LE -r 48000 -c 1 -d 2 '$outdir/hw0-routed.wav'"
	if [[ -s "$outdir/hw0-routed.wav" ]]; then
		sox_stat "$outdir/hw0-routed.wav" >"$outdir/hw0-routed.sox-stat"
		log "hw0_routed samples=$(awk '/Samples read/ {print $3}' "$outdir/hw0-routed.sox-stat") max=$(awk '/Maximum amplitude/ {print $3}' "$outdir/hw0-routed.sox-stat") rms=$(awk '/RMS     amplitude/ {print $3}' "$outdir/hw0-routed.sox-stat")"
	fi

	run_sh "filtered boot audio messages" "$sudo_cmd dmesg | grep -Ei 'acdb|calib|adsp|remoteproc|q6|afe|asm|voice|wcd|mbhc|slim|mic|audio|sound|apr|firmware|fail|error' | tail -260"

	reset_capture_routes
	log "Capture routes reset to off."
	log "Done. Summary: $log_file"
}

main "$@"
