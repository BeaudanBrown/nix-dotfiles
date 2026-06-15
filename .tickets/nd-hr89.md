---
id: nd-hr89
status: open
deps: []
links: [nd-87m2]
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
