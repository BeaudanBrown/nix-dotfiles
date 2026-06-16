# OnePlus Fresh-Agent Loop Bootstrap

This is the seed prompt for fresh agents working on the `oneplus` host. Start here for normal chat handoffs, `/aloop`-style workers, and post-reboot resumes.

## Current source of truth

- Current epic: `nd-gv62` — OnePlus fresh-agent hardware stabilization loop.
- Current state doc: `docs/oneplus-bringup.md`.
- Loop policy: `docs/oneplus-agent-loop.md`.
- Reusable tools: `docs/oneplus-debug-tools.md`.
- Boot handoff: `docs/pi-boot-resume.md` and `.pi/boot-system.md`.

Archived bring-up notes, superseded tickets, and git history are evidence only. Do not treat them as a task list. It is acceptable to retry an old line of investigation when current evidence supports it; after doing so, integrate the result into this current pipeline.

## Start every iteration

Run/read:

```sh
git status --short
git log --oneline -n 10
tk show nd-gv62
tk ready
tk blocked
```

Then read the selected child ticket and the relevant section of `docs/oneplus-bringup.md`.

If the current epic is closed with a `STOP` note, stop immediately unless the user explicitly reopens or creates new work.

## Selecting work

Pick one ready child ticket under `nd-gv62`. Do not work the epic itself unless you are grooming the backlog. If no focused ticket is ready, use `nd-qbd8` to scan current runtime and create the next focused ticket.

Each iteration should do exactly one focused thing:

1. Assess the previous committed change and its ticket notes.
2. Inspect current runtime/log state; do not assume old logs still apply.
3. Make one fix, one experiment, or one grounded documentation/ticket update.
4. If the investigation expands, create/link a new focused ticket instead of growing scope.
5. Record evidence and decisions with `tk add-note`.
6. Review `git diff` and `git status --short`.
7. Commit exactly one coherent commit for the iteration when running under `/aloop`; diagnostic tools must not commit.
8. Amend/squash/rebase your own local commits when needed so each iteration commit is meaningful and reviewable.
9. Leave a clear next suggested inquiry in the ticket note.

If a change makes the device worse, prefer reverting that exact change and recording why before trying an unrelated fix.

Do not use tooling that auto-commits results. Tools may write artifacts or ticket-ready notes, but the agent decides when and what to commit after reviewing the complete diff.

## Tooling rule

Before writing new scripts, check `docs/oneplus-debug-tools.md`. If you create a reusable diagnostic or helper, promote it into the repo when practical:

1. script under `scripts/`;
2. Nix wrapper/package/app in the flake when useful;
3. short entry in `docs/oneplus-debug-tools.md`;
4. ticket note showing how it was used.

One-off shell snippets are fine for small inspection, but repeated or complex diagnostics should become reusable tools.

## Validation and reboot

For Nix config changes, run focused evaluation when practical. Do not run broad builds unless the active work requires it and project policy allows it.

If a boot generation or reboot is needed:

1. Commit the coherent state first, keeping the commit focused and reviewable.
2. Seed `.pi/boot-task.md` and the optional next-loop advisory with:

   ```sh
   nix run .#oneplus-loop-seed-reboot -- <ticket-id> --checks "<post-boot checks>"
   ```

3. Run `nr` only when preparing the next boot generation; do not run `nix eval` immediately before `nr`.
4. On OnePlus, a single `sudo -n /run/current-system/sw/bin/reboot` handoff is allowed only for a ticket that explicitly needs boot validation.
5. If running inside `/aloop`, finish with `ALOOP_RESULT: needs_reboot` so the live supervisor stops and the selected ticket may remain open for post-boot validation.
6. The resumed agent must assess the result and must not automatically start another reboot. It may run the optional `/aloop 1 nd-gv62` continuation only after recording evidence and confirming the worktree is clean.

If no reboot is chosen, finish by leaving the repo/tickets in a state where a new fresh agent can start from this bootstrap and continue.

## Stop condition

The sentinel ticket `nd-y7lt` closes the loop. When it becomes ready, perform a final current-state scan. If no actionable work remains, add a ticket note beginning with `STOP:` and close `nd-y7lt` and `nd-gv62`. Future agents should stop when they see that state.
