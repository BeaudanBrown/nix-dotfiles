# Pi Boot Resume

This repo supports a generic boot-resume debugging handoff. For OnePlus loop work, start from `docs/oneplus-loop-bootstrap.md` and use this file only for reboot mechanics.

## Files

- `.pi/boot-system.md` is tracked and contains persistent boot-resume operating instructions.
- `.pi/boot-task.md` is untracked/ignored and contains the current ticket-specific reboot seed.
- `.pi/boot-next-loop.md` is untracked/ignored and optionally contains an advisory next `/aloop 1 ...` command to use after validation.
- `scripts/pi-boot-seed.sh` writes `.pi/boot-task.md` for generic handoffs.
- `nix run .#oneplus-loop-seed-reboot -- <ticket-id> --checks "..."` writes OnePlus-specific `.pi/boot-task.md`; add `--next-loop` to also write `.pi/boot-next-loop.md`.
- `scripts/pi-boot-resume.sh` opens/attaches the `default` tmux session, starts a `pi-boot-resume` window, concatenates the system prompt, task seed, and optional next-loop advisory, then opens the most recently modified Pi session and sends the prompt there. It is now manual-only and is not autostarted by the OnePlus graphical session.

## Workflow

1. Commit the coherent code/docs/ticket state.
2. For OnePlus loop work, seed the reboot task with:

   ```sh
   nix run .#oneplus-loop-seed-reboot -- <ticket-id> --checks "<post-boot checks>"
   ```

   For generic handoffs, use `scripts/pi-boot-seed.sh "..."` or edit `.pi/boot-task.md`.
3. Include the active ticket id, expected post-boot checks, and explicit stop/continue criteria.
4. Run `nr` only if preparing a new boot generation. Do not run `nix eval` immediately before `nr`.
5. Reboot only when the active ticket needs boot validation.
6. If the reboot is part of `/aloop`, finish the worker with `ALOOP_RESULT: needs_reboot` so the live supervisor stops without treating the open ticket as a failure.
7. If a boot-resume prompt is needed, start Ghostty manually with `scripts/pi-boot-resume.sh`; the OnePlus graphical session no longer autostarts it.
8. The resumed agent assesses the result, records evidence in tk/docs/git, and must not automatically start another reboot.
9. If `.pi/boot-next-loop.md` was explicitly seeded and is present, use it only after validation is recorded and the worktree is clean.

## OnePlus constraints

- One ticket may use exactly one `sudo -n /run/current-system/sw/bin/reboot` handoff after the seed and commit are in place.
- Reboot stress loops, chained automated reboots, and automatic `nr && reboot` loops are not approved.
- If `.pi/boot-task.md` is stale or references a closed ticket, ignore it as a navigation hint and fall back to `docs/oneplus-loop-bootstrap.md` plus current tk state.
- If `.pi/boot-next-loop.md` is present, it is advisory rather than automatic and exists only by opt-in seed; validate the reboot result first, then run the suggested `/aloop 1 nd-gv62` only if safe.
- On the OnePlus host, `wheel` currently has temporary passwordless sudo for bring-up diagnostics. Remove that host setting once the phone is stable.
