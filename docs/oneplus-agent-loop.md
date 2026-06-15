# OnePlus Agent Loop Workflow

This document is the operating contract for running long `/aloop` sessions on the OnePlus backlog.

Primary epic:

- `nd-8dw3` — OnePlus issue-loop stabilization backlog

The goal is that `/aloop 30 nd-8dw3` can keep making progress without being derailed by stale debugging history, unsupported reboot automation, or kernel-build rabbit holes.

## Source of truth

Use this priority order:

1. tk tickets and notes, especially `tk show nd-8dw3` and the selected child ticket.
2. Current runtime state and current logs.
3. Current concise docs:
   - `docs/oneplus-bringup.md`
   - `docs/pi-boot-resume.md`
4. Specific historical evidence only when needed:
   - `docs/oneplus-audio-trials/`
   - `docs/archive/oneplus-bringup-history-20260615.md`
   - git history

Do not use archived generation narratives as a task list. If a useful historical fact matters, write the concise conclusion into the active ticket or current docs.

## Per-ticket loop

Each worker should:

1. Read the epic and selected ticket.
2. Read recent notes for related tickets if relevant.
3. Check `git status --short` and recent `git log --oneline`.
4. Inspect current logs/runtime/code enough to verify the issue still exists.
5. Form a small plan.
6. Implement one focused change or document a grounded finding.
7. If new work is discovered, create/link a tk ticket instead of expanding scope indefinitely.
8. Add tk notes with evidence, commands, and decisions.
9. Commit coherent code/docs/ticket changes together.
10. Close the ticket only when its acceptance criteria are met or when it is explicitly blocked by kernel work / no longer actionable.

## Creating follow-up tickets

Create new tickets when investigation finds:

- a distinct log/error cluster;
- a separate subsystem;
- a prerequisite;
- a hypothesis requiring its own experiment;
- a kernel/device-tree/kernel-config change that normal `/aloop` must not perform.

New child tickets should use `--parent nd-8dw3`. Add dependencies with `tk dep` when ordering matters.

If the final sentinel ticket is open, make it depend on new actionable tickets so it cannot close the epic prematurely.

## Kernel rebuild boundary

Normal `/aloop` must not start kernel rebuilds or kernel development.

If an issue cannot be pursued further without rebuilding/patching the kernel or producing a new kernel closure:

1. Record the exact blocker and evidence in the current ticket.
2. Create/link a focused kernel-work ticket if that future work is worth tracking.
3. Close the current non-kernel ticket as blocked by kernel work, or leave the new kernel ticket as the remaining work.
4. Move on to other ready tickets.

This keeps long loops from spending all iterations in expensive kernel work.

## Reboot boundary

Standard `/aloop` is safe for non-reboot work. OnePlus now has approval for a constrained single-cycle reboot handoff, not an unlimited unattended reboot loop.

For a ticket that explicitly needs OnePlus boot validation, an agent may invoke the proven wrapper once with `sudo -n /run/current-system/sw/bin/reboot` only after all of these are true:

1. The coherent code/docs/ticket state is committed.
2. `.pi/boot-task.md` names the ticket, expected post-boot checks, and stop/continue criteria.
3. `/run/current-system/sw/bin/reboot` resolves to the OnePlus high-priority wrapper and `kernel.sysrq = 1`.
4. The ticket/user explicitly calls for reboot validation; do not add reboots to unrelated work.
5. The boot-task seed tells the resumed agent not to start another reboot automatically.

After the resumed agent reaches graphical login / `pi-boot-resume`, it must inspect runtime state, record results in tk/docs/git, and then close/continue/split the ticket. Do not run chained reboot loops, repeated stress cycles, or automatic `nr && reboot` loops unless a later ticket separately validates that broader policy.

SysRq-backed `reboot` and `shutdown` wrappers exist on OnePlus. `nd-pcdw` validated one clean `sudo -n /run/current-system/sw/bin/reboot` cycle on 2026-06-16: the next boot resumed pi/tmux handoff, journal history remained available, root was read-write, Wi-Fi/Tailscale were up, and no failed units were present. The persistent journal did not retain explicit wrapper/kmsg markers, so future post-boot checks should treat marker absence as inconclusive rather than failure when other handoff evidence is clean.

### `nd-pcdw` reboot-wrapper validation result

Evidence from the completed one-cycle validation:

1. Booted host was `oneplus`; `/run/current-system/sw/bin/reboot` resolved to `/nix/store/ziadansm1m0nk0qfa0q4ri1z4y0dc62c-reboot/bin/reboot`.
2. `kernel.sysrq = 1`.
3. `journalctl --list-boots` showed the previous boot ending at 2026-06-15 23:24:52 AEST and the current boot starting at 2026-06-15 23:27:11 AEST.
4. Runtime health after resume: `/` mounted `rw`, `wlan0` had `192.168.68.126/24`, Tailscale had `100.64.0.1/32`, gateway ping succeeded, `systemctl --failed` reported 0 failed units, and the tmux/pi handoff reached the resumed agent.
5. No shutdown hang, remoteproc crashdump hang, or root I/O error was found in the retained previous/current boot evidence searched for this ticket.

## Final sentinel / no-more-work behavior

A final sentinel ticket should remain blocked by all known actionable OnePlus issue tickets.

When it becomes ready, the worker should:

1. Run a final scan of tk, current docs, current journal warnings, failed services, and obvious hardware/runtime state.
2. If actionable issues remain, create child tickets and make the sentinel depend on them.
3. If no actionable issues remain, add a note explaining what was checked, close the sentinel, add an epic closeout note, and close `nd-8dw3`.

After the epic is closed, future agents should stop immediately unless the user explicitly reopens the epic or creates a new ticket.

## Validation expectations

- Docs-only changes: review for contradictions and broken internal references.
- Nix config changes: run focused evaluation when practical; do not build unless explicitly requested.
- `nr`: only when preparing a boot generation for a ticket that needs it.
- Kernel work: flag and ticket, do not perform in normal `/aloop`.
