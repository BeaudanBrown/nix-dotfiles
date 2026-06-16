---
id: nd-ihy2
status: closed
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

**2026-06-16T12:07:24Z**

HANDOFF: Added nix run .#oneplus-audio-readings bounded helper plus docs/oneplus-audio-readings.md. Current runtime evidence: speaker sink monitor positive (max 0.11999878/rms 0.07627125); transient AMIC4/ADC4 bottom-mic PipeWire and ALSA captures open but record exact zero (48000 samples, max/rms 0). Tests: bash -n, helper --help, direct --route-bottom-mic run, nix eval flake app, git diff --check. Remaining risk: physical bottom mic still zero via non-kernel userspace route; no kernel build/patch/switch used.

**2026-06-16T12:07:24Z**

HANDOFF from nd-ihy2: Audio loop now has a repeatable non-kernel one-shot readings app. Bluetooth/stop-sentinel tickets can proceed after this unless user wants deeper non-kernel mic experiments despite exact-zero AMIC4/ADC4 captures.
