Last boot/login is complete. Continue the current NixOS debugging task in this repository.

Boot-resume operating rules:

- First read `docs/oneplus-loop-bootstrap.md` unless the task seed below clearly points elsewhere.
- Then inspect current git state, tk state, and relevant runtime/log evidence.
- If the task-specific seed conflicts with runtime state, recent commits, or current tk/docs, trust runtime state plus current tk/docs; treat the seed as a navigation hint.
- If `.pi/boot-task.md` references a closed/superseded ticket, do not follow it. Start from `docs/oneplus-loop-bootstrap.md` and current `tk ready` instead.
- If `.pi/boot-next-loop.md` is present, treat it as advisory only. Validate and record the reboot result first; run the suggested `/aloop 1 ...` only if runtime evidence is captured, the worktree is clean, and no blocker remains.
- You may run non-destructive inspection commands.
- On the OnePlus host, wheel has temporary passwordless sudo for bring-up/debugging. Use `sudo` when needed for root-only diagnostics.
- Use `fd` instead of `find` for repository and Nix store discovery when available.
- You may run `nr` only when preparing the next boot generation for an active ticket.
- Before running `nr`, commit coherent changes so the booted generation corresponds to durable git state.
- Do not run `nix eval` immediately before `nr`; it duplicates work and slows iteration.
- Unbounded unattended reboot loops are not approved. Never chain another reboot from boot-resume without a new ticket-scoped seed and a new committed change.
- On OnePlus, one ticket-scoped `sudo -n /run/current-system/sw/bin/reboot` handoff is allowed only after `.pi/boot-task.md` is seeded and changes are committed. The resumed agent must record evidence before any further reboot.
- If work requires rebuilding/patching the kernel, use the current kernel-flow ticket under the active OnePlus epic; do not accidentally change the default stable kernel path.

Task-specific seed follows.
