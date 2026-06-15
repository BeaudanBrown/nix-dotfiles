---
id: nd-wzyq
status: open
deps: []
links: [nd-24hg]
created: 2026-06-15T14:06:10Z
type: task
priority: 2
assignee: Beaudan Brown
parent: nd-8dw3
tags: [oneplus, touch, ghostty, tmux]
---
# Add OnePlus terminal touch-scroll workaround

Raw OnePlus touchscreen swipes reach the kernel/lisgd gesture layer, but Ghostty/tmux does not receive wheel escape bytes for finger swipes. The missing translation is at the Wayland terminal/app layer, not the touchscreen driver.

## Design

Evaluate a narrow workaround such as a Ghostty/niri/lisgd-specific touch-to-wheel or touch-to-tmux-scroll bridge that only applies when a terminal is focused. Avoid broad global one-finger vertical gestures that break normal touch use.

## Acceptance Criteria

Focused OnePlus terminal scroll workaround is implemented and validated, or upstream Ghostty/niri limitation is documented with a minimal replacement-terminal recommendation.
