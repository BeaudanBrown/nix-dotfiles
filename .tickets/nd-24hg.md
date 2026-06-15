---
id: nd-24hg
status: closed
deps: [nd-qo2o]
links: [nd-wzyq]
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

## Notes

**2026-06-15T14:06:19Z**

Investigation evidence on live oneplus: host is oneplus, Wayland/niri session focused on Ghostty/tmux. systemctl status oneplus-niri-gestures shows lisgd active on /dev/input/by-path/platform-a90000.i2c-event and recent user swipes logged as Swipe distance plus one Execute toggle-overview. This proves raw touchscreen swipes reach the kernel/lisgd gesture layer; disappearance is above evdev/global-gesture handling, at Wayland terminal/Ghostty/tmux conversion to wheel/escape bytes. Updated scripts/record-oneplus-touch-events.sh to include oneplus-niri-gestures journal evidence in future captures. Created follow-up nd-wzyq for a scoped terminal touch-scroll workaround.

**2026-06-15T14:06:19Z**

HANDOFF: identified layer as Wayland terminal/app translation above evdev/lisgd; updated record-oneplus-touch-events.sh to capture lisgd service logs; verification: bash -n scripts/record-oneplus-touch-events.sh passed. Remaining touch-scroll implementation is tracked by nd-wzyq.
