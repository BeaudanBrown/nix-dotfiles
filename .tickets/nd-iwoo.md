---
id: nd-iwoo
status: closed
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

## Notes

**2026-06-16T12:27:30Z**

HANDOFF: Validated OnePlus mic measurement path on current runtime. Ran scripts/oneplus-audio-readings.sh --seconds 1 --route-bottom-mic --outdir /tmp/oneplus-audio-readings-nd-iwoo-helper, then repeated AMIC4/ADC4 with direct arecord S16 1s/2s, arecord S24 1s, and direct pw-record S16 2s into /tmp/oneplus-mic-validate-nd-iwoo. Independent byte/sample inspection found valid captures with nonzero_bytes=0 peak=0 rms=0 across ALSA and PipeWire; arecord S32_LE failed because only S16_LE/S24_LE are available. Documented result in docs/oneplus-audio-readings.md and docs/oneplus-bringup.md. Next touchpoint: nd-h6lz ALSA/PipeWire capture matrix can proceed treating exact-zero as a real capture result, not helper artifact.
