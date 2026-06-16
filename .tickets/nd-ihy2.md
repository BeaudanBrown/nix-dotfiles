---
id: nd-ihy2
status: open
deps: []
links: []
created: 2026-06-16T00:57:56Z
type: task
priority: 3
assignee: Beaudan Brown
parent: nd-gv62
tags: [oneplus, audio, mic, userspace, current]
---
# Stabilize OnePlus speaker and bottom microphone readings

Get consistent positive runtime readings from both speaker playback and microphone capture without compiling, patching, or switching kernels. Focus on ALSA/PipeWire/WirePlumber/UCM/mixer routing, current services, and repeatable debug tooling.

## Design

Start from current behavior, not old trial instructions. Keep the stable speaker path intact unless current evidence proves a small reversible userspace change is needed. Use `docs/oneplus-debug-tools.md`, `debug-oneplus-mic`, `oneplus-mic-trial`, ALSA/PipeWire inspection, and focused mixer/UCM experiments. Do not build kernels, add kernel patches, or create a test-kernel path under this ticket; if evidence clearly points below userspace, record the blocker and keep exploring non-kernel validation/fallbacks.

## Acceptance Criteria

A repeatable non-kernel procedure records positive/zero readings for speaker playback and each available microphone/capture source. Any small ALSA/PipeWire/UCM/service fix that improves consistency is implemented and validated without regressing speaker playback; otherwise the exact remaining non-kernel limits and evidence are documented in tk/docs.

## Notes

**2026-06-16T11:55:34Z**

Retargeted per user direction: pursue non-kernel speaker/microphone reading stabilization only. Do not compile kernels, create a test-kernel path, or add kernel patches; focus on ALSA/PipeWire/WirePlumber/UCM/mixer/service experiments and repeatable positive/zero measurements.
