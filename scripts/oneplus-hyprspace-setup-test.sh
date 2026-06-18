#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat <<'EOF'
Usage: oneplus-hyprspace-setup-test [--windows <n>] [--open-overview] [--dry-run]

Create deterministic hyprspace-test-* windows on workspaces 1..n, focus workspace 1, optionally open overview, and print a concise clients summary.
This helper uses bounded polling only and never rebuilds, reboots, loops indefinitely, or commits.
EOF
}

is_uint() { [[ ${1:-} =~ ^[0-9]+$ ]]; }
require_uint() {
	local name="$1" value="$2"
	if ! is_uint "$value" || [[ $value -lt 1 ]]; then
		echo "$name must be a positive integer: $value" >&2
		exit 2
	fi
}

windows=3
open_overview=0
dry_run=0
while [[ $# -gt 0 ]]; do
	case "$1" in
	-h | --help)
		usage
		exit 0
		;;
	--windows)
		[[ $# -ge 2 ]] || {
			echo "--windows requires a value" >&2
			exit 2
		}
		windows="$2"
		shift 2
		;;
	--open-overview)
		open_overview=1
		shift
		;;
	--dry-run)
		dry_run=1
		shift
		;;
	*)
		echo "Unknown argument: $1" >&2
		usage >&2
		exit 2
		;;
	esac
done
require_uint windows "$windows"

hc() {
	if [[ $dry_run -eq 1 ]]; then
		printf '+ hyprctl %q' "$1"
		shift || true
		printf ' %q' "$@"
		printf '\n'
	else
		hyprctl "$@"
	fi
}

client_json() { hyprctl clients -j; }
addresses_for_title() {
	local title="$1"
	client_json | jq -r --arg title "$title" '.[] | select((.title == $title) or (.initialTitle == $title)) | .address'
}

printf 'Preparing %s Hyprspace preview-drag test windows (dry_run=%s)\n' "$windows" "$dry_run"

if [[ $dry_run -eq 0 ]]; then
	client_json | jq -r '.[] | select((.title | startswith("hyprspace-test-")) or (.initialTitle | startswith("hyprspace-test-"))) | .address' |
		while IFS= read -r addr; do
			[[ -n $addr ]] && hyprctl dispatch closewindow "address:$addr" >/dev/null || true
		done
	sleep 0.4
else
	echo '+ close existing hyprspace-test-* windows'
fi

for i in $(seq 1 "$windows"); do
	title="hyprspace-test-$i"
	if [[ $dry_run -eq 1 ]]; then
		echo "+ ghostty --title=$title -e sh -lc 'printf ...; sleep infinity'"
		echo "+ wait for $title, move to workspace $i"
		continue
	fi

	ghostty --title="$title" -e sh -lc "printf '\033]0;$title\007'; echo $title; sleep infinity" >/dev/null 2>&1 &
	addr=""
	for _ in $(seq 1 30); do
		addr="$(addresses_for_title "$title" | head -n1 || true)"
		[[ -n $addr ]] && break
		sleep 0.1
	done
	if [[ -z $addr ]]; then
		echo "Timed out waiting for $title" >&2
		exit 1
	fi
	hyprctl dispatch movetoworkspacesilent "$i,address:$addr" >/dev/null
done

if [[ $dry_run -eq 1 ]]; then
	echo '+ hyprctl dispatch workspace 1'
	[[ $open_overview -eq 1 ]] && echo '+ hyprctl dispatch overview:open'
	echo '+ hyprctl clients summary'
	exit 0
fi

hyprctl dispatch workspace 1 >/dev/null
if [[ $open_overview -eq 1 ]]; then
	hyprctl dispatch overview:open >/dev/null
fi

hyprctl clients -j | jq -r '.[] | select((.title | startswith("hyprspace-test-")) or (.initialTitle | startswith("hyprspace-test-"))) | "\(.address)\tws=\(.workspace.id)\ttitle=\(.title)\tinitial=\(.initialTitle)"' | sort
