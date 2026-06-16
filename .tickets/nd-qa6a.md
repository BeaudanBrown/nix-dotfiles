---
id: nd-qa6a
status: closed
deps: [nd-6g7r]
links: []
created: 2026-06-16T00:57:56Z
type: task
priority: 2
assignee: Beaudan Brown
parent: nd-gv62
tags: [oneplus, kernel, nix, tooling, cancelled]
---
# Cancelled: patchable OnePlus kernel experiment flow

This ticket is intentionally closed. Per user direction, do not pursue a patchable/test kernel path, kernel compilation, or kernel patching for current OnePlus audio work.

## Design

Keep the default OnePlus host on the known-good pinned kernel closure. Current audio work should prefer non-kernel runtime and userspace exploration: ALSA, PipeWire, WirePlumber, UCM, mixer controls, service ordering, and repeatable measurement tooling.

## Acceptance Criteria

No kernel experiment flow is required for the active loop. Downstream tickets no longer depend on this ticket; if future kernel development is explicitly requested, create a new focused ticket rather than reopening this one.

## Notes

**2026-06-16T11:52:27Z**

Cancelled per user direction: do not pursue patchable/test kernel or kernel compilation for now. Keep the known-good pinned kernel and focus OnePlus audio work on non-kernel userspace/runtime experiments.
