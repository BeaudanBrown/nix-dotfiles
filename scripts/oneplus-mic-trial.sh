#!/usr/bin/env bash
set -euo pipefail

mode="pmos-runtime"
label="trial"
outdir=""
commit_result=0
allow_dirty=0
reset_note="unspecified"

usage() {
	cat <<EOF
Usage: $0 [--mode MODE] [--label LABEL] [--reset-note NOTE] [--outdir OUTDIR] [--commit] [--allow-dirty]

Run one focused OnePlus mic diagnostic and write a committed-ready trial record
that ties the result to the exact git/config/boot/firmware state.

Recommended cold-boot retrace:
  nix run .#oneplus-mic-trial -- --label coldboot-pmos-runtime --reset-note 'full power off 30s' --commit

Defaults:
  --mode pmos-runtime
  --label trial
EOF
}

while [[ $# -gt 0 ]]; do
	case "$1" in
	--mode)
		mode="${2:-}"
		shift 2
		;;
	--mode=*)
		mode="${1#--mode=}"
		shift
		;;
	--label)
		label="${2:-}"
		shift 2
		;;
	--label=*)
		label="${1#--label=}"
		shift
		;;
	--reset-note)
		reset_note="${2:-}"
		shift 2
		;;
	--reset-note=*)
		reset_note="${1#--reset-note=}"
		shift
		;;
	--outdir)
		outdir="${2:-}"
		shift 2
		;;
	--outdir=*)
		outdir="${1#--outdir=}"
		shift
		;;
	--commit)
		commit_result=1
		shift
		;;
	--allow-dirty)
		allow_dirty=1
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

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

if [[ $allow_dirty -ne 1 ]] && [[ -n $(git status --porcelain) ]]; then
	echo "Refusing to run trial with a dirty tree." >&2
	echo "Commit/stash current changes first, or pass --allow-dirty for an intentionally dirty trial." >&2
	git status --short >&2
	exit 1
fi

safe_label="$(printf '%s' "$label" | tr -cs 'A-Za-z0-9._-' '-' | sed 's/^-//; s/-$//')"
if [[ -z $safe_label ]]; then
	safe_label="trial"
fi
stamp="$(date -u +%Y%m%dT%H%M%SZ)"
outdir="${outdir:-/tmp/oneplus-mic-debug-${safe_label}-${stamp}}"
record_dir="docs/oneplus-audio-trials"
record="$record_dir/${stamp}-${safe_label}.md"
mkdir -p "$record_dir"

pre_head="$(git rev-parse --short=12 HEAD)"
pre_head_full="$(git rev-parse HEAD)"
current_system="$(readlink -f /run/current-system 2>/dev/null || true)"
current_firmware="$(readlink -f /run/current-system/firmware 2>/dev/null || true)"
current_entry="$(bootctl status 2>/dev/null | awk -F': ' '/Current Entry/ {print $2; exit}' || true)"
default_entry="$(bootctl status 2>/dev/null | awk -F': ' '/Default Boot Loader Entry/ {getline; getline; if ($1 ~ /[[:space:]]*title/) print $2; exit}' || true)"
uptime_before="$(cut -d' ' -f1 /proc/uptime 2>/dev/null || true)"
ucm_dump_hash="unavailable"
if command -v alsaucm >/dev/null 2>&1; then
	ucm_dump_hash="$(alsaucm -c O6T dump text 2>/dev/null | sha256sum | awk '{print $1}' || true)"
fi

printf 'Running OnePlus mic trial: label=%s mode=%s outdir=%s\n' "$label" "$mode" "$outdir"
debug-oneplus-mic --mode "$mode" "$outdir"

summary="$outdir/summary.txt"
result_lines=""
if [[ -f $summary ]]; then
	result_lines="$(grep -E '(^|[[:space:]])(code=|samples=|max=|rms=|RUNNING|dmesg_lines=)' "$summary" | tail -n 80 || true)"
fi

status_lines=""
for status_file in "$outdir"/*.proc-asound; do
	[[ -e $status_file ]] || continue
	status_lines+=$'\n'
	status_lines+="$(grep -H -E 'state:|hw_ptr|appl_ptr|format:|rate:|channels:' "$status_file" | tail -n 80 || true)"
done

cat >"$record" <<EOF
# OnePlus mic trial: ${label}

## Identity

- UTC time: ${stamp}
- Label: ${label}
- Mode: ${mode}
- Reset note: ${reset_note}
- Artifact: ${outdir}
- Pre-trial git HEAD: ${pre_head_full} (${pre_head})
- Current system: ${current_system}
- Current boot entry: ${current_entry}
- Default boot entry: ${default_entry}
- Firmware path: ${current_firmware}
- UCM dump sha256: ${ucm_dump_hash}
- Uptime before trial seconds: ${uptime_before}

## Result summary

\`\`\`text
${result_lines:-no max/rms/status result lines found; inspect artifact summary.txt}
\`\`\`

## PCM runtime excerpts

\`\`\`text
${status_lines:-no proc/asound runtime excerpts found}
\`\`\`

## Re-run command

\`\`\`sh
nix run .#oneplus-mic-trial -- --mode '${mode}' --label '${label}' --reset-note '${reset_note}'
\`\`\`
EOF

printf 'Trial record written: %s\n' "$record"

if [[ $commit_result -eq 1 ]]; then
	git add "$record"
	git commit -m "Record OnePlus mic trial ${safe_label}"
fi
