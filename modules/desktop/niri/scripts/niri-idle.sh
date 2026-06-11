#!/usr/bin/env bash
exec swayidle -w \
	timeout 900 'pidof hyprlock || hyprlock' \
	timeout 1800 'systemctl suspend' \
	before-sleep 'hyprlock'
