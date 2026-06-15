---
id: nd-pcdw
status: in_progress
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

## Notes

**2026-06-15T14:25:22Z**

HANDOFF: Added explicit nd-pcdw one-cycle SysRq wrapper validation checklist to docs/oneplus-agent-loop.md and docs/pi-boot-resume.md, and seeded .pi/boot-task.md for the next manual reboot handoff. Non-invasive preflight on current OnePlus boot: hostname=oneplus, /run/current-system/sw/bin/reboot resolves to /nix/store/ziadansm1m0nk0qfa0q4ri1z4y0dc62c-reboot/bin/reboot, kernel.sysrq=1; retained recent boot journals did not contain ONEPLUS SYSRQ markers. Tests/checks run: rg/read docs, hostname/uname/readlink/sysctl/journalctl. Remaining risk/next touchpoint: requires the actual supervised command sudo -n /run/current-system/sw/bin/reboot and post-boot evidence before closing or approving automation.
