---
id: nd-h6lz
status: open
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
