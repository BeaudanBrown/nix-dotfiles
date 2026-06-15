---
id: nd-24hg
status: open
deps: [nd-qo2o]
links: []
created: 2026-06-15T13:54:54Z
type: bug
priority: 2
assignee: Beaudan Brown
parent: nd-8dw3
tags: [oneplus, touch, ghostty, tmux]
---
# Investigate touch scrolling in Ghostty/tmux

Finger swipes on OnePlus do not appear to reach tmux as wheel events despite valid bindings; initial captures saw no raw motion events.

## Design

Use or document scripts/record-oneplus-touch-events.sh outside chat. Determine whether swipes produce raw evdev events, Wayland touch events, terminal mouse escape bytes, or Ghostty-internal scrollback only. Implement fix or create layer-specific follow-up.

## Acceptance Criteria

The event layer where scrolling disappears is identified. A focused fix is implemented or a follow-up ticket captures the layer-specific blocker.
