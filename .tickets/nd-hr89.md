---
id: nd-hr89
status: closed
deps: []
links: [nd-87m2, nd-n819]
created: 2026-06-15T14:11:06Z
type: bug
priority: 2
assignee: Beaudan Brown
parent: nd-8dw3
tags: [oneplus, audio, mic, kernel]
---
# Investigate OnePlus bottom-mic kernel/ADSP exact-zero state

Bottom mic userspace routing reaches RUNNING ALSA capture and powers the expected WCD934x/DAPM path, but samples intermittently remain exact-zero. Generation 70 speaker-only UCM plus manual module-alsa-source produced non-zero direct and app-visible capture; generation 71 boot-time source and generation 72 manual/full-poweroff retraces recorded exact-zero with the same visible ALSA/DAPM runtime state.

## Design

Treat UCM/PipeWire shape as already constrained: keep speaker-only UCM, do not reintroduce UCM Mic1, and do not use a static PipeWire context source. Investigate kernel/ADSP/AFE/SLIM/codec reset-depth or init differences, especially WCD934x/q6afe/slim channel-map/runtime state around SLIM TX7/MultiMedia2/hw:O6T,1. Normal /aloop workers must not build kernels; use traceable oneplus-mic-trial artifacts as repro evidence and do kernel work in an explicit kernel-development flow.

## Acceptance Criteria

A kernel/device-tree/ADSP-side fix or diagnostic patch explains or resolves exact-zero bottom-mic capture without regressing speaker playback, or the blocker is narrowed to a specific upstream/kernel subsystem with collected evidence and next patch target.

## Notes

**2026-06-15T14:16:36Z**

Context from nd-fuc6: current boot has one qcom,slim-ngd-ctrl QMI wait timeout, but SLIM controller later registers/emits SAT messages and historical non-zero bottom-mic captures occurred with this warning class. Treat as background for kernel/ADSP/SLIM reset-state investigation, not a proven root cause.

**2026-06-15T14:42:28Z**

Evidence/decision: ran current OnePlus mic trial in pmos-runtime mode on generation 74 current system/default generation 75. Result record docs/oneplus-audio-trials/20260615T144115Z-nd-hr89-current-kernel-boundary.md shows S16/S24 captures both exact-zero (max/rms 0.000000) while hw:O6T,1 is RUNNING with advancing pointers and no dmesg delta. This reproduces the lower-level failure with speaker-only UCM/no static source and no userspace routing change left to make in normal /aloop. Split explicit kernel-development follow-up nd-n819 for sdm845/wcd934x/q6afe/slim path: MultiMedia2 -> SLIMBUS_0_TX -> AIF1_CAP -> SLIM TX0 -> CDC_IF TX0 -> DEC0 -> ADC4/AMIC4.

**2026-06-15T14:42:28Z**

HANDOFF: documented current exact-zero retrace and narrowed blocker to kernel/ADSP ASoC path; created linked follow-up nd-n819 and made nd-nebp depend on it; verification was runtime oneplus-mic-trial pmos-runtime plus docs review; remaining risk is kernel trace/patch work only.
