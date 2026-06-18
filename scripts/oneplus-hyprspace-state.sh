#!/usr/bin/env bash
set -euo pipefail

run() {
	printf '\n## %s\n' "$*"
	"$@" || true
}

hostname || true
run hyprctl plugin list
run hyprctl monitors
run hyprctl activeworkspace
run hyprctl clients
run hyprctl getoption general:layout
run hyprctl getoption plugin:overview:panelHeight
run hyprctl getoption plugin:overview:gapsIn
run hyprctl getoption plugin:overview:gapsOut
run hyprctl getoption plugin:overview:exitOnSwitch
run hyprctl getoption plugin:overview:switchOnDrop
run hyprctl getoption plugin:overview:previewDrag
run hyprctl getoption plugin:overview:debugHitboxes
