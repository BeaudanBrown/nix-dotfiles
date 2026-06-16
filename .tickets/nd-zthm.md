---
id: nd-zthm
status: closed
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

## Notes

**2026-06-16T12:38:24Z**

HANDOFF: audited current OnePlus ALSA mixer controls and recorded artifacts under /tmp/oneplus-mixer-nd-zthm-20260616T123432Z; relevant controls include MultiMedia/AIF/CDC_IF/ADC/AMIC/DMIC/DEC families and no MICBIAS control was exposed. Runtime-only bounded trials found baseline/conservative route exact-zero, but high-gain ADC4 over TX7/DEC7 and TX0/DEC0 produced non-zero hw:O6T,1 samples without breaking speaker playback; final oneplus-audio-readings speaker probe remained positive. Remaining risk: non-zero may be clipped/noise-only, so nd-vnpn should compare these deltas with UCM/vendor routes before any persistent change.
