---
id: nd-gv62
status: open
deps: []
links: []
created: 2026-06-16T00:57:55Z
type: epic
priority: 2
assignee: Beaudan Brown
tags: [oneplus, agent-loop, stabilization, current]
---
# OnePlus fresh-agent hardware stabilization loop

Current-source-of-truth epic for fresh agents iterating on the OnePlus host. Agents start from docs/oneplus-loop-bootstrap.md, pick one ready child ticket, assess current runtime and previous git/tk state, make one focused change, record evidence, and either seed a one-shot reboot handoff or leave a clear next inquiry.

## Design

Keep this epic focused on current work. Superseded tickets and old debug records are archived for evidence only. Durable current state belongs in docs/oneplus-bringup.md, reusable procedure/tooling in docs/oneplus-agent-loop.md and docs/oneplus-debug-tools.md, and active work in this epic's child tickets.

## Acceptance Criteria

Fresh agents can start from the bootstrap prompt, discover current ready work without stale ticket noise, iterate one focused OnePlus fix at a time, promote reusable scripts into Nix-wrapped tools, and stop when the sentinel records that no actionable work remains.


## Notes

**2026-06-16T01:01:41Z**

BOOTSTRAP CLEANUP: created current fresh-agent loop docs, moved superseded OnePlus tickets/debug records out of active .tickets/current docs into docs/archive, reset boot-resume seed, and left current work under nd-gv62 only. Fresh agents should start from docs/oneplus-loop-bootstrap.md; next suggested inquiry is either nd-qbd8 current runtime scan or a focused ready child ticket.

**2026-06-16T01:07:19Z**

GIT POLICY UPDATE: removed oneplus-mic-trial auto-commit behavior (--commit now errors) and documented that agents must review diffs and manually create/amend/squash focused commits. Next cleanup before more loop work should be history surgery on the existing noisy commits, done only with explicit rewrite/push guidance.

**2026-06-16T02:03:16Z**

ORDERING UPDATE: top-level loop work is intentionally dependency-gated so /aloop picks up the previous iteration cleanly: nd-qbd8 current scan first, then nd-6g7r display classification, then nd-qa6a patchable kernel flow, then nd-ihy2 mic tracing, then nd-y7lt sentinel. Future agents should add new tickets into this chain by dependency, not by relying only on prose.

**2026-06-16T02:20:09Z**

TOOL LIBRARY UPDATE: added closed child nd-1jlj for OnePlus agent UI observe/control tools. Future agents should extend docs/oneplus-debug-tools.md and the flake-wrapped scripts rather than creating ad-hoc screenshot/touch snippets.
