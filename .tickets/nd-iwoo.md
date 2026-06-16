---
id: nd-iwoo
status: open
deps: []
links: []
created: 2026-06-16T12:20:03Z
type: task
priority: 2
assignee: Beaudan Brown
parent: nd-gv62
tags: [oneplus, audio, mic, userspace, current]
---
# Validate OnePlus mic measurement path

Prove the current exact-zero microphone reading is a real capture result rather than an artifact of the helper, WAV analysis, sample format, duration, or PipeWire/ALSA command choice.

## Design

Run bounded non-kernel comparisons with the existing audio readings helper plus direct arecord/PipeWire captures, multiple rates/formats/durations where safe, and independent peak/RMS inspection. Do not change persistent routing.

## Acceptance Criteria

A tk/doc note records commands and confirms whether exact-zero is reproducible across at least two capture/analysis paths, or identifies and fixes a measurement bug.
