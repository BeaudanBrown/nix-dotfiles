---
id: nd-y7b7
status: closed
deps: [nd-ts1j]
links: []
created: 2026-06-16T12:20:04Z
type: task
priority: 4
assignee: Beaudan Brown
parent: nd-gv62
tags: [oneplus, audio, mic, fallback, userspace, current]
---
# Document OnePlus microphone fallback input options

Identify practical non-internal-mic input paths if the built-in bottom mic remains exact-zero.

## Design

Check feasible fallback classes such as USB-C audio, headset/BT after Bluetooth classification, network audio, or external capture devices. Do not require purchasing hardware; document what is testable now and what needs user hardware.

## Acceptance Criteria

A concise fallback matrix is recorded with available/not-available/test-needed status and recommended practical input path while internal mic remains blocked.

## Notes

**2026-06-16T13:03:01Z**

HANDOFF: Documented fallback input matrix in docs/oneplus-audio-readings.md and summarized it in docs/oneplus-bringup.md. Runtime inventory checked only O6T ALSA card, speaker monitor source, BT service active with hci0 soft-blocked, and Wi-Fi/Tailscale up; no attached USB/BT external mic source. Preferred practical path is class-compliant USB-C mic/headset adapter; BT remains deferred to nd-d6hc; network/remote audio is an app-level workaround. Validation: rg checked new doc anchors.
