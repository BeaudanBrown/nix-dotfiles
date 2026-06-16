---
id: nd-h6lz
status: closed
deps: [nd-iwoo]
links: []
created: 2026-06-16T12:20:03Z
type: task
priority: 2
assignee: Beaudan Brown
parent: nd-gv62
tags: [oneplus, audio, mic, alsa, pipewire, userspace, current]
---
# Map OnePlus ALSA and PipeWire capture matrix

Enumerate and test every visible ALSA/PipeWire capture endpoint to find whether any internal microphone route returns non-zero samples.

## Design

Use arecord -l/-L, pactl/wpctl/pw-cli inspection, and bounded captures from hw/plughw/default/PipeWire sources. Record positive/zero/error for each endpoint. Avoid persistent config changes unless a tiny reversible fix is obvious.

## Acceptance Criteria

A matrix of capture devices/sources with positive/zero/error results is recorded; any endpoint producing non-zero capture is identified and a minimal use path is documented.

## Notes

**2026-06-16T12:32:56Z**

HANDOFF: mapped current ALSA/PipeWire capture matrix in docs/oneplus-audio-readings.md; evidence from /tmp/oneplus-capture-matrix-nd-h6lz-20260616T123012Z and /tmp/oneplus-audio-readings-nd-h6lz-route shows hw/plughw 0,1 and transient oneplus_bottom_mic_trial open but exact-zero, other real capture endpoints fail, and no non-zero internal mic route was found; validation commands: arecord -l/-L, pactl/wpctl/pw-cli enumeration, bounded arecord/pw-record captures, scripts/oneplus-audio-readings.sh --seconds 1 --route-bottom-mic; next touchpoint nd-zthm mixer controls.
