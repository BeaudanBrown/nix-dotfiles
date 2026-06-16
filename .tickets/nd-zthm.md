---
id: nd-zthm
status: open
deps: [nd-h6lz]
links: []
created: 2026-06-16T12:20:03Z
type: task
priority: 2
assignee: Beaudan Brown
parent: nd-gv62
tags: [oneplus, audio, mic, alsa, mixer, userspace, current]
---
# Audit OnePlus mic mixer controls

Determine whether a muted/zero-gain/routed-off ALSA control causes exact-zero bottom microphone capture.

## Design

Snapshot amixer contents before/after, identify capture-related ADC/DEC/TX/DMIC/AMIC/MICBIAS/SLIM/MultiMedia controls, and try small runtime-only reversible control changes with bounded recordings after each change.

## Acceptance Criteria

Relevant mixer controls and tested deltas are recorded with before/after readings; either a control change yields non-zero capture without breaking speaker playback, or likely mixer-only fixes are exhausted.
