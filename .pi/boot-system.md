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
- Unattended reboot loops are not approved yet, so do not attempt automatic reboot loops.
- When a reboot is needed, stop after preparing the generation and ask the user to manually reboot unless ticket `nd-pcdw` has explicitly validated automated reboot safety.
- If work cannot proceed without rebuilding or patching the kernel, record the blocker in tk, create/link a kernel-work ticket if useful, close or unblock the current ticket appropriately, and move on rather than building a kernel in normal `/aloop`.

Task-specific seed follows.
