---
id: nd-pcdw
status: open
deps: [nd-zs91]
links: []
created: 2026-06-15T13:54:54Z
type: task
priority: 2
assignee: Beaudan Brown
parent: nd-8dw3
tags: [oneplus, reboot, agent-loop]
---
# Validate OnePlus SysRq reboot wrappers before automated reboot loops

Recent OnePlus config adds high-priority reboot/shutdown wrappers using SysRq sync/remount/reboot-or-poweroff; validate before allowing unattended /aloop reboot cycles.

## Design

Manually test reboot/poweroff behavior across at least one full agent handoff. Update docs to either allow constrained automated reboot or keep manual reboot only. Until this ticket closes successfully, all reboot-required tickets must stop before reboot.

## Acceptance Criteria

Manual evidence proves whether wrappers are reliable enough for automation. Docs and agent-loop instructions are updated accordingly.
