---
id: nd-v48v
status: closed
deps: []
links: []
created: 2026-06-16T01:34:54Z
type: task
priority: 2
assignee: Beaudan Brown
parent: nd-gv62
tags: [oneplus, agent-loop]
---
# Implement reboot-aware OnePlus aloop workflow

Add pi-harness needs_reboot support and nix-dotfiles reboot seed tooling/docs for robust OnePlus fresh-agent loops.

## Acceptance Criteria

pi-harness supports needs_reboot handoff; OnePlus seed helper and boot-resume next-loop advisory are documented and exposed; diagnostic tools do not auto-commit.


## Notes

**2026-06-16T01:38:14Z**

Implemented reboot-aware aloop workflow: pi-harness supports ALOOP_RESULT needs_reboot with one-worker-commit enforcement; nix-dotfiles exposes oneplus-loop-seed-reboot and boot-resume next-loop advisory. Validation: pi-harness nix run .#verify passed; bash -n scripts passed; nix eval package name passed; nix run .#oneplus-loop-seed-reboot -- --help and temp seed smoke test passed.
