#!/usr/bin/env bash
set -euo pipefail

card="${ONEPLUS_AUDIO_CARD:-O6T}"
outdir=""
duration="${ONEPLUS_AUDIO_SECONDS:-2}"
route_bottom_mic=0
play_speaker=1

usage() {
	cat <<EOF
Usage: $0 [--outdir DIR] [--seconds N] [--no-speaker] [--route-bottom-mic]

Collect bounded, repeatable non-kernel OnePlus audio readings.

Default behavior is read-only with respect to mixer/routing: it records the
current PipeWire sink monitor and every ALSA/PipeWire capture source it can see.

Options:
  --route-bottom-mic  Temporarily set the known AMIC4/ADC4 bottom-mic route,
                      load a transient PipeWire Pulse source named
                      oneplus_bottom_mic_trial, record it, then unload it.
  --no-speaker        Skip bounded speaker playback/monitor capture.
  --seconds N         Capture/playback duration in seconds (default: 2).
  --outdir DIR        Artifact directory (default: /tmp/oneplus-audio-readings-*)
EOF
}

while [[ $# -gt 0 ]]; do
	case "$1" in
	--outdir)
		outdir="${2:-}"
		shift 2
		;;
	--outdir=*)
		outdir="${1#--outdir=}"
		shift
		;;
	--seconds)
		duration="${2:-}"
		shift 2
		;;
	--seconds=*)
		duration="${1#--seconds=}"
		shift
		;;
	--route-bottom-mic)
		route_bottom_mic=1
		shift
		;;
	--no-speaker)
		play_speaker=0
		shift
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		echo "Unexpected argument: $1" >&2
		usage >&2
		exit 2
		;;
	esac
done

case "$duration" in
'' | *[!0-9]*)
	echo "--seconds must be an integer" >&2
	exit 2
	;;
esac

outdir="${outdir:-/tmp/oneplus-audio-readings-$(date -u +%Y%m%dT%H%M%SZ)}"
mkdir -p "$outdir"
summary="$outdir/summary.tsv"
log="$outdir/log.txt"
printf 'kind\tname\tstatus\tsamples\tmax\trms\tartifact\tnote\n' >"$summary"

have() { command -v "$1" >/dev/null 2>&1; }

note() { printf '%s\n' "$*" | tee -a "$log"; }

safe_name() {
	printf '%s' "$1" | tr -cs 'A-Za-z0-9._-' '-' | sed 's/^-//; s/-$//'
}

wav_stat() {
	node - "$1" <<'JS'
const fs = require('fs');
const path = process.argv[2];
try {
  const b = fs.readFileSync(path);
  const channels = b.readUInt16LE(22);
  const bits = b.readUInt16LE(34);
  const dataOffset = b.indexOf(Buffer.from('data')) + 8;
  if (dataOffset < 8 || bits !== 16) throw new Error(`unsupported wav bits=${bits}`);
  const samples = Math.floor((b.length - dataOffset) / 2);
  let max = 0;
  let sumSq = 0;
  for (let off = dataOffset; off + 1 < b.length; off += 2) {
    const v = b.readInt16LE(off);
    const a = Math.abs(v);
    if (a > max) max = a;
    sumSq += v * v;
  }
  const rms = samples > 0 ? Math.sqrt(sumSq / samples) : 0;
  const scale = 32767;
  console.log(`samples=${samples} max=${(max / scale).toFixed(8)} rms=${(rms / scale).toFixed(8)} channels=${channels}`);
} catch (e) {
  console.log(`samples=unknown max=unknown rms=unknown error=${String(e.message || e)}`);
}
JS
}

write_probe_wav() {
	node - "$1" "$duration" <<'JS'
const fs = require('fs');
const path = process.argv[2];
const duration = Number(process.argv[3]);
const rate = 48000;
const channels = 2;
const bytesPerSample = 2;
const frames = rate * duration;
const dataBytes = frames * channels * bytesPerSample;
const b = Buffer.alloc(44 + dataBytes);
b.write('RIFF', 0);
b.writeUInt32LE(36 + dataBytes, 4);
b.write('WAVEfmt ', 8);
b.writeUInt32LE(16, 16);
b.writeUInt16LE(1, 20);
b.writeUInt16LE(channels, 22);
b.writeUInt32LE(rate, 24);
b.writeUInt32LE(rate * channels * bytesPerSample, 28);
b.writeUInt16LE(channels * bytesPerSample, 32);
b.writeUInt16LE(16, 34);
b.write('data', 36);
b.writeUInt32LE(dataBytes, 40);
for (let i = 0; i < frames; i++) {
  const sample = Math.round(0.12 * 32767 * Math.sin(2 * Math.PI * 440 * i / rate));
  const off = 44 + i * 4;
  b.writeInt16LE(sample, off);
  b.writeInt16LE(sample, off + 2);
}
fs.writeFileSync(path, b);
JS
}

record_result() {
	local kind="$1" name="$2" status="$3" wav="$4" note_text="${5:-}"
	local stat samples max rms
	if [[ -s $wav ]]; then
		stat="$(wav_stat "$wav")"
		samples="$(printf '%s\n' "$stat" | sed -n 's/.*samples=\([^ ]*\).*/\1/p')"
		max="$(printf '%s\n' "$stat" | sed -n 's/.*max=\([^ ]*\).*/\1/p')"
		rms="$(printf '%s\n' "$stat" | sed -n 's/.*rms=\([^ ]*\).*/\1/p')"
	else
		samples="0"
		max="0"
		rms="0"
	fi
	if awk "BEGIN { exit !(${max:-0} > 0) }" 2>/dev/null; then
		status="positive"
	elif awk "BEGIN { exit !(${samples:-0} > 0) }" 2>/dev/null; then
		status="zero"
	elif [[ $status == ok ]]; then
		status="zero"
	fi
	printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$kind" "$name" "$status" "${samples:-unknown}" "${max:-unknown}" "${rms:-unknown}" "$wav" "$note_text" | tee -a "$summary"
}

capture_pw_source() {
	local source="$1" name wav err status
	name="$(safe_name "$source")"
	wav="$outdir/pw-${name}.wav"
	err="$outdir/pw-${name}.err"
	status="ok"
	if timeout "$((duration + 3))" pw-record --target "$source" --rate 48000 --channels 1 --format s16 --sample-count "$((duration * 48000))" --media-type Audio --media-category Capture --media-role Test "$wav" >"$err" 2>&1; then
		status="ok"
	else
		status="fail"
	fi
	record_result "pipewire-source" "$source" "$status" "$wav" "$(tr '\n\t' '  ' <"$err" | head -c 220)"
}

capture_alsa_device() {
	local dev="$1" name wav err status
	name="$(safe_name "$dev")"
	wav="$outdir/alsa-${name}.wav"
	err="$outdir/alsa-${name}.err"
	status="ok"
	timeout "$((duration + 3))" arecord -q -D "$dev" -f S16_LE -r 48000 -c 1 -d "$duration" "$wav" >"$err" 2>&1 || status="fail"
	record_result "alsa-capture" "$dev" "$status" "$wav" "$(tr '\n\t' '  ' <"$err" | head -c 220)"
}

note "OnePlus audio readings: outdir=$outdir card=$card seconds=$duration route_bottom_mic=$route_bottom_mic"
{
	date -u +%FT%TZ
	hostname
	cat /proc/asound/cards 2>/dev/null || true
	wpctl status 2>/dev/null || true
} >"$outdir/context.txt"

if [[ $play_speaker -eq 1 ]]; then
	probe="$outdir/speaker-probe.wav"
	write_probe_wav "$probe"
	if have pw-record && have pw-play; then
		monitor_name="$(pactl get-default-sink 2>/dev/null || true).monitor"
		[[ $monitor_name == .monitor ]] && monitor_name=""
		monitor="$(pactl list sources short 2>/dev/null | awk -v name="$monitor_name" '$2 == name { print $1; exit }')"
		[[ -z $monitor ]] && monitor="$monitor_name"
		if [[ -n $monitor_name ]]; then
			wav="$outdir/speaker-monitor.wav"
			err="$outdir/speaker-monitor.err"
			status="ok"
			pw-record --target "$monitor" --rate 48000 --channels 2 --format s16 --sample-count "$((duration * 48000))" "$wav" >"$err" 2>&1 &
			rec_pid=$!
			sleep 0.2
			pw-play "$probe" >>"$err" 2>&1 || status="fail"
			wait "$rec_pid" || status="fail"
			record_result "speaker-monitor" "$monitor_name" "$status" "$wav" "bounded 440Hz probe through default sink"
		fi
	elif have aplay; then
		aplay -q -D "hw:$card,0" "$probe" || true
		record_result "speaker-playback" "hw:$card,0" "played-no-monitor" "$probe" "aplay fallback; artifact is generated probe, not monitor capture"
	fi
fi

mapfile -t alsa_devices < <(arecord -l 2>/dev/null | awk 'match($0, /^card ([0-9]+):.*device ([0-9]+):/, m) { print "hw:" m[1] "," m[2] }' | sort -u)
for dev in "${alsa_devices[@]}"; do
	capture_alsa_device "$dev"
done

mapfile -t pw_sources < <(pactl list sources short 2>/dev/null | awk '{print $2}' | grep -v '\.monitor$' || true)
for src in "${pw_sources[@]}"; do
	capture_pw_source "$src"
done

loaded_module=""
cleanup() {
	if [[ -n ${loaded_module:-} ]]; then
		pactl unload-module "$loaded_module" >/dev/null 2>&1 || true
	fi
}
trap cleanup EXIT

if [[ $route_bottom_mic -eq 1 ]]; then
	note "Applying transient AMIC4/ADC4 bottom-mic route and PipeWire Pulse source"
	amixer -c "$card" cset name='MultiMedia2 Mixer SLIMBUS_0_TX' 1 >/dev/null
	amixer -c "$card" cset name='AIF1_CAP Mixer SLIM TX7' 1 >/dev/null
	amixer -c "$card" cset name='CDC_IF TX7 MUX' DEC7 >/dev/null
	amixer -c "$card" cset name='ADC MUX7' AMIC >/dev/null
	amixer -c "$card" cset name='AMIC MUX7' ADC4 >/dev/null
	amixer -c "$card" cset name='AMIC4_5 SEL' AMIC4 >/dev/null
	amixer -c "$card" cset name='ADC4 Volume' 12 >/dev/null
	amixer -c "$card" cset name='DEC7 Volume' 84 >/dev/null
	loaded_module="$(pactl load-module module-alsa-source device=hw:"$card",1 source_name=oneplus_bottom_mic_trial source_properties=device.description=OnePlus_Bottom_Mic_Trial format=s16le rate=48000 channels=1)"
	sleep 0.5
	capture_pw_source oneplus_bottom_mic_trial
	capture_alsa_device "hw:$card,1"
fi

note "Summary: $summary"
column -t -s $'\t' "$summary" 2>/dev/null || cat "$summary"
