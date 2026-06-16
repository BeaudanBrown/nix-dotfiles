---
id: nd-ts1j
status: open
deps: [nd-296h]
links: []
created: 2026-06-16T12:20:04Z
type: task
priority: 3
assignee: Beaudan Brown
parent: nd-gv62
tags: [oneplus, audio, mic, firmware, dsp, userspace, current]
---
# Inspect OnePlus audio firmware and DSP runtime logs

Look for non-kernel-visible ADSP/firmware/SLIM/QMI/runtime errors that correlate with exact-zero microphone capture.

## Design

Inspect current boot firmware paths, dmesg/journal around ADSP/audio/SLIM/WCD/Q6 capture starts, and service logs before/after bounded capture attempts. Do not patch or build kernels.

## Acceptance Criteria

Relevant firmware/DSP/audio log evidence is recorded; any userspace-remediable firmware/path/service issue is fixed, otherwise the remaining blocker is described without creating kernel-build work.
