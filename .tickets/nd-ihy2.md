---
id: nd-ihy2
status: open
deps: [nd-qa6a]
links: []
created: 2026-06-16T00:57:56Z
type: task
priority: 2
assignee: Beaudan Brown
parent: nd-gv62
tags: [oneplus, audio, mic, kernel]
---
# Trace OnePlus bottom microphone exact-zero capture

Use the patchable kernel experiment flow to instrument or patch the Qualcomm ASoC/ADSP/SLIM/WCD934x capture path for the bottom microphone exact-zero state.

## Design

Start from current behavior, not old trial instructions. Keep the stable speaker-only userspace shape unless current evidence overturns it. Prefer reusable trace/debug tooling and record results through docs/oneplus-debug-tools.md conventions.

## Acceptance Criteria

Trace evidence or a patch explains/restores bottom mic capture without regressing speaker playback, or narrows the blocker to a specific upstream subsystem with enough evidence for future work.
