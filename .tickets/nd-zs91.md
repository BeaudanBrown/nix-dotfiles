---
id: nd-zs91
status: closed
deps: []
links: []
created: 2026-06-15T13:54:54Z
type: task
priority: 2
assignee: Beaudan Brown
parent: nd-8dw3
tags: [oneplus, docs, reboot, agent-loop]
---
# Document /aloop vs OnePlus reboot-resume workflow

Clarify how standard /aloop should interact with OnePlus boot-generation and manual reboot-resume workflows.

## Design

Update docs/pi-boot-resume.md and/or add docs/oneplus-agent-loop.md. Explain that normal /aloop is fine for non-reboot tickets. Reboot-required tickets must commit coherent changes, seed .pi/boot-task.md, run nr only when appropriate, and stop for manual reboot. SysRq reboot/shutdown wrappers exist but are not approved for unattended loops until explicitly validated. Resumed agents should record post-boot evidence in tk notes/docs/git before deciding continue/close/split.

## Acceptance Criteria

Docs answer whether standard /aloop works with the reboot pattern: not automatically yet; use manual boot-resume handoff. Agents have explicit stop conditions for reboot-required work and know not to run unattended reboot loops.

## Notes

**2026-06-15T14:01:00Z**

Added docs/oneplus-agent-loop.md and updated docs/pi-boot-resume.md/.pi/boot-system.md with /aloop reboot boundaries, manual boot-resume handoff, kernel rebuild boundary, and final sentinel behavior.
