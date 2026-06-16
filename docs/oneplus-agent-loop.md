# OnePlus Agent Loop Policy

Use `docs/oneplus-loop-bootstrap.md` as the canonical fresh-agent prompt. This file defines the operating boundaries for that loop.

## Active backlog

Current epic:

- `nd-gv62` — OnePlus fresh-agent hardware stabilization loop

Superseded tickets are archived historical evidence. Do not use them as current navigation unless a current ticket explicitly asks for history.

## Iteration contract

Each agent performs one focused iteration, usually through:

```text
/aloop 1 nd-gv62
```

Iteration contract:

1. Start from `docs/oneplus-loop-bootstrap.md`.
2. Pick one ready child ticket under `nd-gv62`.
3. Inspect current runtime/log/code state before trusting prior conclusions.
4. Implement one fix, one experiment, or one documentation/ticket cleanup.
5. Promote reusable scripts into Nix-wrapped repo tools when practical; extend the existing OnePlus UI/tool library instead of writing ad-hoc snippets.
6. Add a concise tk note with evidence, commands, result, and next suggested inquiry.
7. Create one coherent commit for the iteration. Diagnostic tools must not commit.
8. Amend/squash/rebase your own local commits when needed so the history stays meaningful.

If new work is discovered, create a focused child ticket and link/depend it as needed. Do not hide new scope inside an unrelated ticket.

## Queue discipline

The current OnePlus loop uses tk dependencies as the queue, not just priority or prose. `/aloop` should normally see one obvious ready leaf ticket. Maintain that invariant:

- Keep `nd-qbd8` as the current-runtime scan/reset point.
- Gate display work after the scan: `nd-6g7r <- nd-qbd8`.
- Treat `nd-qa6a` as cancelled unless a future user explicitly requests kernel builds again.
- Keep bottom-mic/speaker work non-kernel focused under `nd-ihy2`; do not compile kernels or create a test-kernel path in normal loop work.
- Keep `nd-y7lt` blocked on every known actionable ticket.

When an agent discovers new work, decide where it belongs in the chain:

1. If it must happen before the current ticket can finish, create a prerequisite ticket and add `tk dep <current> <new-prereq>`.
2. If it is the next sensible follow-up after the current ticket, create it under `nd-gv62`, make it depend on the current ticket, and make later/sentinel tickets depend on it as needed.
3. If it is optional or speculative, add a note/link rather than unblocking the queue.

At handoff, ticket notes should say what changed, what evidence was checked, and which ticket should become ready next.

For UI/display/touch/app-navigation work, prefer the shared observe-control tools in `docs/oneplus-debug-tools.md`: capture a screenshot, read it, perform one explicit touch/key action, capture again, then record the result. New UI helpers should be flake apps with `--help`, dry-run support for actions, bounded one-shot behavior, and no auto-commit behavior.

## History policy

Closed tickets, archived notes, old trial records, and git history are evidence, not instructions. It is fine to retry old approaches if current evidence justifies it, but the new result must be integrated into the current docs/tickets so future agents do not need to replay the archive.

## Kernel boundary

Normal loop iterations must not enter kernel development for the current OnePlus audio work. Do not build kernels, create a patchable/test-kernel path, or add kernel patches unless the user gives new explicit direction in the current session.

If evidence points below userspace, record the blocker and exact evidence in tk/docs, keep the default OnePlus config on the known-good pinned kernel, and continue with other non-kernel validation or fallback experiments where useful. The old kernel-enablement ticket `nd-qa6a` is closed/cancelled; current mic work proceeds through `nd-ihy2` without that dependency.

## Reboot boundary

A single ticket-scoped OnePlus reboot handoff is allowed when boot validation is genuinely needed. Before rebooting:

1. commit the coherent state;
2. seed `.pi/boot-task.md` and optional `.pi/boot-next-loop.md` with:

   ```sh
   nix run .#oneplus-loop-seed-reboot -- <ticket-id> --checks "<post-boot checks>"
   ```

3. run `nr` only if preparing a new boot generation;
4. confirm `/run/current-system/sw/bin/reboot` is the OnePlus wrapper and `kernel.sysrq = 1` when relying on the approved wrapper;
5. run at most one `sudo -n /run/current-system/sw/bin/reboot`;
6. finish the `/aloop` worker with `ALOOP_RESULT: needs_reboot` so the live supervisor stops cleanly.

The resumed agent must inspect the result, record evidence, and decide close/revert/split/continue. It may use `.pi/boot-next-loop.md` to run `/aloop 1 nd-gv62` only after validation is recorded and the worktree is clean. It must not chain another reboot automatically.

If no reboot is needed, finish by leaving tk notes clear enough for a fresh agent to start the next iteration from the bootstrap.

## Git history policy

Agents, not tools, decide when to commit. Diagnostic tools must not auto-commit. A good `/aloop` iteration ends with exactly one clean commit containing the code/docs/ticket changes for that focused unit of work. If an iteration creates noisy intermediate commits, clean them before handoff with amend/squash/rebase while they are still local. After a local loop batch, it is acceptable to clean history before sharing. Do not rewrite shared history unless the user explicitly asks.

## Sentinel / stop behavior

`nd-y7lt` is the no-more-work sentinel. It should depend on all known actionable current tickets. When ready:

1. scan current docs, `tk ready/blocked`, failed units, recent logs, and obvious hardware/runtime state;
2. create new focused tickets if actionable work remains, and make the sentinel depend on them;
3. if no work remains, add a `STOP:` note, close the sentinel, and close `nd-gv62`.

After the epic is closed with `STOP:`, future agents should stop unless the user explicitly starts a new phase.
