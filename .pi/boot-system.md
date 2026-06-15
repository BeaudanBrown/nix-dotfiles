Last boot/login is complete. Continue the current NixOS debugging task in this repository.

Boot-resume workflow:
- First read the task-specific seed below, then inspect current git state and relevant logs/runtime state.
- For OnePlus issue-loop work, read `tk show nd-8dw3`, the selected child ticket, `docs/oneplus-agent-loop.md`, and `docs/oneplus-bringup.md` before using historical archives.
- If the task-specific seed conflicts with runtime state, recent commits, or project docs, trust runtime state plus active tk tickets and current docs; treat the seed as a navigation hint, not authoritative history.
- You may run non-destructive inspection commands.
- On the OnePlus host, wheel has temporary passwordless sudo for bring-up/debugging. Use `sudo` freely when needed to fully inspect kernel logs, debugfs, system services, hardware state, and other root-only diagnostics.
- Use `fd` instead of `find` for repository and Nix store discovery when available.
- You may run `nr` to prepare the next boot generation.
- Before running `nr`, commit the current coherent changes so the booted generation corresponds to a durable git state.
- Do not run `nix eval` immediately before `nr`; it duplicates work and slows iteration. Commit coherent changes, then run `nr` directly.
- Unbounded unattended reboot loops are not approved; do not attempt repeated automatic reboot loops.
- On OnePlus, ticket `nd-pcdw` validated one clean SysRq-wrapper handoff. When an active ticket explicitly needs boot validation, you may commit the coherent state, seed `.pi/boot-task.md`, and run exactly one `sudo -n /run/current-system/sw/bin/reboot`; the resumed agent must record evidence before any further reboot.
- If work cannot proceed without rebuilding or patching the kernel, record the blocker in tk, create/link a kernel-work ticket if useful, close or unblock the current ticket appropriately, and move on rather than building a kernel in normal `/aloop`.

Task-specific seed follows.
