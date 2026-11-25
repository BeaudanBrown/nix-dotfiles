# shellcheck shell=bash
# Runs as a Sunshine prep command inside Grill's graphical session.
fail() {
	printf 'Steam Big Picture: %s\n' "$*" >&2
	exit 1
}

dispatch() {
	local result
	if ! result=$(hyprctl dispatch "$@") || [[ $result != ok ]]; then
		fail "Hyprland rejected $*: $result"
	fi
}

stream_id=$(hyprctl -j monitors | jq -er '.[] | select(.name == "STREAM") | .id') ||
	fail 'STREAM output is not available'
if ! hyprctl -j workspaces | jq -e 'any(.[]; .name == "streaming" and .monitor == "STREAM")' >/dev/null; then
	fail 'The streaming workspace is not on STREAM'
fi

dispatch focusmonitor STREAM
dispatch workspace name:streaming

# Launch outside Sunshine's service cgroup, so ending or restarting the
# stream service does not kill Steam or a running game.
steam_bin=$(command -v steam) || fail 'Steam executable is not available'
systemd-run --user --collect --quiet --property=PartOf=graphical-session.target -- "$steam_bin" 'steam://open/bigpicture'

window=""
for ((attempt = 0; attempt < 100; attempt++)); do
	window=$(hyprctl -j clients | jq -c '
    first(.[] | select(.class == "steam" and .title == "Steam Big Picture Mode")) // empty
  ')
	[[ -z $window ]] || break
	sleep 0.2
done
[[ -n $window ]] || fail 'Timed out waiting for the Big Picture window'

address=$(jq -er '.address | select(test("^0x[0-9a-fA-F]+$"))' <<<"$window")
if [[ $(jq -r '.workspace.name' <<<"$window") != streaming ]]; then
	dispatch movetoworkspacesilent "name:streaming,address:$address"
fi
dispatch focuswindow "address:$address"
if [[ $(jq -r '.fullscreen' <<<"$window") != 2 ]]; then
	dispatch fullscreenstate '2 2'
fi

for ((attempt = 0; attempt < 20; attempt++)); do
	if hyprctl -j clients | jq -e --arg address "$address" --argjson monitor "$stream_id" '
    any(.[]; .address == $address and .workspace.name == "streaming" and .monitor == $monitor and .fullscreen == 2)
  ' >/dev/null; then
		exit 0
	fi
	sleep 0.1
done
fail 'Big Picture did not become fullscreen on STREAM'
