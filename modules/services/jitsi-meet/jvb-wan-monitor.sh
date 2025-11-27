#!/usr/bin/env bash
set -euo pipefail
STATE_DIR=/var/lib/jvb-wan-monitor
STATE_FILE="$STATE_DIR/wan_ip"
mkdir -p "$STATE_DIR"
chmod 700 "$STATE_DIR"

fetch() { curl -m 5 -fsSL "$1" || true; }

ip=""
for url in \
	https://api.ipify.org \
	https://ifconfig.co/ip \
	https://icanhazip.com; do
	ip=$(fetch "$url" | tr -d ' \n\r\t')
	if [ -n "$ip" ] && printf '%s' "$ip" | grep -Eq '^[0-9]{1,3}(\.[0-9]{1,3}){3}$'; then
		break
	else
		ip=""
	fi
done

if [ -z "$ip" ]; then
	echo "jvb-wan-monitor: No WAN IPv4 detected" >&2
	exit 0
fi

last=""
if [ -f "$STATE_FILE" ]; then
	last=$(cat "$STATE_FILE" 2>/dev/null || true)
fi

if [ "$ip" != "$last" ]; then
	echo "$ip" >"$STATE_FILE"
	echo "jvb-wan-monitor: WAN IP changed: ${last:-none} -> $ip"
	systemctl try-restart jitsi-videobridge.service
fi
