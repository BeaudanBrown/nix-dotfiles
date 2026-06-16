---
id: nd-ts1j
status: closed
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

## Notes

**2026-06-16T12:59:01Z**

HANDOFF: inspected current OnePlus firmware/DSP runtime logs and recorded evidence in docs/oneplus-audio-readings.md plus docs/oneplus-bringup.md; artifact /tmp/oneplus-fw-dsp-nd-ts1j-20260616T125403Z includes remoteproc state, firmware paths, focused kernel/user logs, and bounded readings. ADSP/CDSP/SLPI stay running, no missing-firmware/remoteproc/service failure was found, speaker remains positive, direct hw:O6T,1 remains exact-zero, and capture attempts correlate with lower-level qcom,slim-ngd TX timeouts plus wcd934x TX port close/overflow logs. No kernel/build/persistent change made; next touchpoint is nd-y7b7 fallback input options.
