---
id: nd-1jlj
status: closed
deps: []
links: []
created: 2026-06-16T02:20:09Z
type: task
priority: 1
assignee: Beaudan Brown
parent: nd-gv62
tags: [oneplus, ui, tooling, current]
---
# Add OnePlus agent UI observe/control tools

Add reusable flake-wrapped helpers for fresh agents to observe and interact with the OnePlus UI through screenshots, touch gestures, and key/text input.

## Design

Provide one-shot scripts for screenshot capture, tap/swipe input, and key/text events. Tools should print clear summaries, fail safely when a backend is missing, and never commit/rebuild/reboot.

## Acceptance Criteria

oneplus-screenshot captures a PNG and prints a Pi read hint; oneplus-touch supports dry-run plus tap/swipe; oneplus-key supports dry-run plus basic key names/text; OnePlus config enables the ydotool daemon/group; docs show observe-act-observe usage and queue/library maintenance rules.


## Notes

**2026-06-16T02:20:09Z**

IMPLEMENTED: added flake apps oneplus-screenshot, oneplus-touch, and oneplus-key; enabled OnePlus-local programs.ydotool for input automation; documented observe-act-observe workflow. Validation included screenshot live capture (1080x2340 PNG), bash -n, flake package evals, help/dry-run smoke tests, ydotool missing-daemon failure path, and OnePlus toplevel drvPath eval.
