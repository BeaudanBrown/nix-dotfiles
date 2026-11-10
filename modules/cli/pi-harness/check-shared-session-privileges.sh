#!/usr/bin/env bash
# Evaluation-only by default. --live additionally reads the current host's flags.
set -euo pipefail
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
live=false
eval_options=(--no-write-lock-file)
while [[ $# -gt 0 ]]; do
	case "$1" in
	--live)
		live=true
		shift
		;;
	--harness-source)
		[[ $# -ge 2 ]] || exit 2
		harness=$(cd "$2" && pwd)
		eval_options+=(--override-input pi-harness "git+file://$harness")
		shift 2
		;;
	*)
		echo "Usage: $0 [--harness-source PATH] [--live]" >&2
		exit 2
		;;
	esac
done
for host in grill nas; do
	value=$(nix eval --json "$repo#nixosConfigurations.$host.config.systemd.user.services.pi-matrix-bridge.serviceConfig.NoNewPrivileges" "${eval_options[@]}")
	if [[ $value != false ]]; then
		echo "FAIL: $host's optional bridge must not poison shared tmux privileges" >&2
		exit 1
	fi
	echo "$host bridge privilege configuration: PASS"
done
$live || exit 0
case "$(hostname)" in
grill | nas) ;;
*)
	echo "Run --live on grill or nas" >&2
	exit 1
	;;
esac
unit=pi-matrix-bridge.service
[[ $(systemctl --user show "$unit" -p ActiveState --value) == active ]]
[[ $(systemctl --user show "$unit" -p NoNewPrivileges --value) == no ]]
bridge=$(systemctl --user show "$unit" -p MainPID --value)
# Explicit -N must not start the shared server during a read-only check.
server=$(tmux -N -S "${XDG_RUNTIME_DIR:?}/tmux-$(id -u)/default" display-message -p '#{pid}')
for pid in "$bridge" "$server" "$$"; do
	[[ $pid =~ ^[1-9][0-9]*$ ]]
	if ! grep -Eq '^NoNewPrivs:[[:space:]]+0$' "/proc/$pid/status"; then
		echo "FAIL: process $pid still has NoNewPrivs; existing processes cannot clear it" >&2
		exit 1
	fi
done
echo "Live bridge, shared tmux server, and invoking shell privileges: PASS"
