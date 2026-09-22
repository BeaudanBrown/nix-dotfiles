#!/usr/bin/env bash
# Evaluation-only by default. --live additionally inspects the current host.
set -euo pipefail
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
case "${1:-}" in
"" | --live) ;;
*)
	echo "Usage: $0 [--live]" >&2
	exit 2
	;;
esac
value=$(nix eval --json "$repo#nixosConfigurations.grill.config.systemd.user.services.pi-managed-session-relay.serviceConfig.NoNewPrivileges")
if [[ $value != false ]]; then
	echo "FAIL: Grill's shared-tmux relay must not set NoNewPrivileges" >&2
	exit 1
fi
echo "Grill relay privilege configuration: PASS"
[[ ${1:-} == --live ]] || exit 0
[[ $(hostname) == grill ]] || {
	echo "Run --live on Grill" >&2
	exit 1
}
[[ $(systemctl --user show pi-managed-session-relay.service -p ActiveState --value) == active ]]
[[ $(systemctl --user show pi-managed-session-relay.service -p NoNewPrivileges --value) == no ]]
relay=$(systemctl --user show pi-managed-session-relay.service -p MainPID --value)
# Require an existing shared server; display-message does not create one.
server=$(tmux -S "${XDG_RUNTIME_DIR:?}/tmux-$(id -u)/default" display-message -p '#{pid}')
for pid in "$relay" "$server" "$$"; do
	[[ $pid =~ ^[1-9][0-9]*$ ]]
	if ! grep -Eq '^NoNewPrivs:[[:space:]]+0$' "/proc/$pid/status"; then
		echo "FAIL: process $pid still has NoNewPrivs; existing processes cannot clear it" >&2
		exit 1
	fi
done
echo "Live relay, shared tmux server, and invoking shell privileges: PASS"
