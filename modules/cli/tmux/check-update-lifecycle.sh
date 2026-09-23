#!/usr/bin/env bash
# shellcheck disable=SC1091
# Disposable units and sockets only. Never restarts the operator's relay/tmux.
set -euo pipefail
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
raw_tmux=$(command -v tmux)
rollout=$(realpath "${1:?Pass the pi-harness scripts/relay-rollout.sh path}")
root=$(mktemp -d)
prefix="pi-update-probe-$$"
shared_unit="$prefix-tmux.service"
relay_unit="$prefix-relay.service"
rollout_unit="$prefix-rollout.service"
cleanup() {
	systemctl --user stop "$rollout_unit" "$relay_unit" "$shared_unit" >/dev/null 2>&1 || true
	"$raw_tmux" -S "$root/foreign" kill-server 2>/dev/null || true
	rm -rf "$root"
}
trap cleanup EXIT
socket="$root/shared"
systemd-run --user --quiet --unit="$shared_unit" --property=Type=exec \
	"$raw_tmux" -D -f /dev/null -S "$socket"
for ((i = 0; i < 100; i++)); do
	"$raw_tmux" -N -S "$socket" display-message -p '#{pid}' >/dev/null 2>&1 && break
	sleep 0.05
done
# Exercise the exact production guard with disposable ownership identifiers.
# shellcheck source=shared-guard.sh
source "$repo/shared-guard.sh"
server_before=$("$raw_tmux" -S "$socket" display-message -p '#{pid}')
"$raw_tmux" -S "$socket" new-session -d -s probe 'sleep 120'
pane_before=$("$raw_tmux" -S "$socket" display-message -p -t probe '#{pane_pid}')
systemd-run --user --quiet --unit="$relay_unit" --property=Type=exec sleep 120
relay_before=$(systemctl --user show "$relay_unit" -p MainPID --value)
# Run the actual harness rollout script through the configured oneshot shape.
# Delay after submission, then destroy ONLY the disposable invoking pane. The
# systemd-owned transaction must still finish and preserve the work pane.
{
	printf '#!%s\nset -euo pipefail\n' "$(command -v bash)"
	printf 'touch %q\nsleep 1\n' "$root/submitted"
	printf 'raw_tmux=%q\nsocket=%q\nshared_unit=%q\n' "$raw_tmux" "$socket" "$shared_unit"
	printf 'source %q\n' "$repo/shared-guard.sh"
} >"$root/guard"
chmod +x "$root/guard"
printf -v invocation '%q ' systemd-run --user --quiet --wait --unit="$rollout_unit" \
	--property=Type=oneshot --property=RemainAfterExit=yes --property="After=$relay_unit" \
	"$(command -v bash)" "$rollout" "$root/guard" "$relay_unit"
invoker=$("$raw_tmux" -S "$socket" new-window -d -P -F '#{window_id}' -t probe "$invocation")
for ((i = 0; i < 100; i++)); do
	[[ -e $root/submitted ]] && break
	sleep 0.05
done
[[ -e $root/submitted ]]
"$raw_tmux" -S "$socket" kill-window -t "$invoker"
for ((i = 0; i < 100; i++)); do
	[[ $(systemctl --user show "$rollout_unit" -p SubState --value) == exited ]] && break
	sleep 0.05
done
[[ $(systemctl --user show "$rollout_unit" -p Result --value) == success ]]
[[ $(systemctl --user show "$rollout_unit" -p SubState --value) == exited ]]
[[ $("$raw_tmux" -S "$socket" display-message -p '#{pid}') == "$server_before" ]]
[[ $("$raw_tmux" -S "$socket" display-message -p -t probe:0 '#{pane_pid}') == "$pane_before" ]]
[[ $(systemctl --user show "$relay_unit" -p MainPID --value) != "$relay_before" ]]
# A legacy server is rejected, not adopted or killed.
"$raw_tmux" -f /dev/null -S "$root/foreign" new-session -d -s foreign 'sleep 120'
if (
	socket="$root/foreign"
	source "$repo/shared-guard.sh"
); then
	echo 'FAIL: accepted a foreign server' >&2
	exit 1
fi
"$raw_tmux" -S "$root/foreign" has-session -t foreign
printf '%s\n' 'PASS: guarded rollout survives invoking-pane death, preserves server/work-pane identities, and rejects legacy ownership'
