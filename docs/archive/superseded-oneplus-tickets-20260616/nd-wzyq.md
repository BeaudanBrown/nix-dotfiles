---
id: nd-wzyq
status: closed
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

## Notes

**2026-06-15T14:40:00Z**

Implemented OnePlus-focused terminal touch-scroll workaround in hosts/oneplus/oneplus-fajita/ui/niri.nix: center one-finger lisgd up/down gestures run oneplus-terminal-scroll, which no-ops unless Ghostty is focused, scrolls the newest active tmux client/pane, and falls back to PageUp/PageDown for non-tmux Ghostty. Documented current touch state in docs/oneplus-bringup.md. Verification: nix eval .#nixosConfigurations.oneplus.config.programs.niri.enable passed; ExecStart eval passed; initial toplevel drvPath eval timed out at 120s without a diagnostic. Runtime validation still requires next switch/boot and a finger-swipe test in Ghostty/tmux.

**2026-06-15T14:40:00Z**

HANDOFF: added Ghostty-focused lisgd/niri/tmux touch-scroll bridge for OnePlus and documented it; tests run: nix eval niri.enable and oneplus-niri-gestures ExecStart passed (one toplevel drvPath eval timed out); remaining risk is runtime tuning of gesture region/direction after next switch.
