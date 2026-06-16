---
id: nd-y7lt
status: open
deps: [nd-qbd8, nd-ihy2, nd-6g7r, nd-d6hc]
links: []
created: 2026-06-16T00:57:56Z
type: task
priority: 4
assignee: Beaudan Brown
parent: nd-gv62
tags: [oneplus, sentinel, stop]
---
# Stop OnePlus loop when no actionable work remains

Final sentinel for the current OnePlus loop. It should be ready only after all known actionable child tickets are closed or intentionally blocked/split.

## Design

When ready, perform one final current-state scan. If work remains, create focused child tickets and make this sentinel depend on them. If no work remains, add a STOP note and close the current epic so future agents stop.

## Acceptance Criteria

A STOP note records the final checks and the epic is closed, or new actionable tickets are created and this sentinel remains blocked.
