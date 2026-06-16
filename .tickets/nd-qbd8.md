---
id: nd-qbd8
status: closed
deps: []
links: [nd-d6hc]
created: 2026-06-16T00:57:56Z
type: task
priority: 0
assignee: Beaudan Brown
parent: nd-gv62
tags: [oneplus, triage, current]
---
# Scan current OnePlus runtime and choose next hardware issue

Perform a fresh current-state scan of the live OnePlus host and convert any actionable hardware/runtime problem into focused child tickets. This is the default ticket when no specific fix ticket is ready.

## Design

Use current logs and runtime only: failed units, journal warnings from the current/previous boot, obvious hardware state, and docs/oneplus-bringup.md. Do not treat old closed ticket notes as active evidence. Create or update focused tickets for concrete issues; if nothing actionable remains, unblock the sentinel.

## Acceptance Criteria

Current runtime scan is recorded in tk notes. Any actionable issues have focused child tickets under the current epic with acceptance criteria; otherwise the sentinel is allowed to close the loop.

## Notes

**2026-06-16T10:55:03Z**

HANDOFF: Current runtime scan complete on host oneplus. Evidence: hostname=oneplus; current boot 7b6dd7bd694e48f08471250ca283e991; no failed system units; wlan0 connected to Party Pies and tailscale reachable; battery 87% discharging/USB health Good; Niri and Ghostty/pi-boot-resume running; user pipewire/wireplumber active with speaker sink and camera devices visible; oneplus-audio-route user service exited successfully and oneplus-mic-source remains manual/inactive. Current journal warnings are mostly duplicate D-Bus service files plus transient Wi-Fi/iwd and USB PHY messages; no current display/DRM/GPU warnings appeared in the focused kernel grep, so nd-6g7r should classify that next from current evidence. New actionable issue found: bluetooth.service is active but bluetoothctl reports no default controller, kernel only shows BNEP, and KDE Connect repeatedly logs missing BlueZ adapter; created linked child nd-d6hc and inserted it after nd-ihy2, with nd-y7lt blocked on it. No code/Nix changes; validation was runtime inspection commands only. Next touchpoint: close this scan and let nd-6g7r become ready.
