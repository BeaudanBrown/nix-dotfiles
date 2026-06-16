---
id: nd-6g7r
status: closed
deps: [nd-qbd8]
links: []
created: 2026-06-16T00:57:56Z
type: task
priority: 1
assignee: Beaudan Brown
parent: nd-gv62
tags: [oneplus, display, gpu, current]
---
# Classify current OnePlus display stability warnings

Check current display/GPU/DRM health and classify whether any live warnings correlate with user-visible instability.

## Design

Use current dmesg/journal and observed display behavior. Ignore old ticket narratives unless needed as git history. If the issue requires kernel/DT work, record the blocker and create/link a focused kernel ticket rather than building in a normal loop iteration.

## Acceptance Criteria

Current display state is documented in tk/docs. Any low-risk config fix is applied, or the issue is closed/no-action/kernel-work with current evidence.

## Notes

**2026-06-16T11:03:12Z**

HANDOFF: Classified live OnePlus display state as no-action/benign. Evidence checked: hostname oneplus boot 7b6dd7bd694e48f08471250ca283e991; systemctl --failed clean; /dev/dri card/render present; Niri Wayland session active on DSI-1 1080x2340@60; current and previous boot kernel journal grep found no DRM/MSM/DPU/Adreno/SMMU/vblank/display matches; current kernel warnings were Wi-Fi/USB only; user journal had one early Niri vblank_throttle warning; screenshots at /tmp/nd-6g7r-niri-screenshot.png and /tmp/nd-6g7r-after-escape.png were readable/non-glitched. Updated docs/oneplus-bringup.md with this classification. No config fix applied; no reboot needed. Next ticket expected ready: nd-qa6a.

**2026-06-16T11:03:27Z**

HANDOFF from nd-6g7r: Display classification found no live kernel/DRM blocker; nd-qa6a can proceed with patchable kernel flow without carrying a display prerequisite. Revisit display only if the single Niri DSI-1 vblank warning recurs or correlates with visible instability.
