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

Standard `/aloop` is safe for non-reboot work. It is not yet an unattended reboot loop.

Until `nd-pcdw` closes with explicit approval for automated reboot loops:

1. Do not run unattended reboot loops.
2. If a change needs boot validation, commit the coherent change first.
3. Seed `.pi/boot-task.md` with the ticket id, expected post-boot checks, and stop/continue criteria.
4. Run `nr` only when the ticket/user explicitly calls for preparing a boot generation.
5. Stop and ask for manual reboot.
6. The resumed agent should inspect runtime state, record results in tk/docs/git, and then close/continue/split.

SysRq-backed `reboot` and `shutdown` wrappers exist on OnePlus, but they are only candidates for automation until `nd-pcdw` validates them.

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
