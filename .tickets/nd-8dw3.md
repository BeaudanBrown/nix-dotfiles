---
id: nd-8dw3
status: open
deps: []
links: []
created: 2026-06-15T13:54:53Z
type: epic
priority: 2
assignee: Beaudan Brown
tags: [oneplus, agent-loop, stabilization, mutable-backlog]
---
# OnePlus issue-loop stabilization backlog

Mutable /aloop scaffolding epic for OnePlus stabilization. Turn journal/log findings into concrete tk-backed work, clean stale docs, and let agents iterate by exploring, planning, implementing focused fixes, and creating/linking follow-up tickets as discoveries emerge.

## Design

Treat this epic as the live OnePlus stabilization backlog. Each /aloop worker should read this epic, the selected child ticket, recent notes, git status/log, and relevant docs; inspect current runtime/log/code state enough to confirm the issue; add or link new tickets for discovered sub-issues instead of silently expanding scope; make a focused fix or documentation improvement; record evidence in tk notes and docs where useful; commit coherent code/docs/ticket changes together. Reboot-required work must commit, seed .pi/boot-task.md, run nr only when appropriate, then stop for manual reboot unless a later ticket explicitly proves automated reboot safe. If an issue cannot be pursued further without kernel rebuild/kernel development, record the blocker, create/link a clear kernel-work ticket if useful, close the current ticket as blocked-by-kernel-work, and move on to other ready work rather than building a kernel in /aloop.

## Acceptance Criteria

Known OnePlus journal issues are represented as concrete child tickets with evidence, likely seams, and acceptance criteria. docs/oneplus-bringup.md is cleaned so current state and open issue pointers are not contradicted by old mic/audio history. Reboot-loop limitations are documented for /aloop. Initial actionable tickets exist for simple non-reboot fixes and deeper hardware investigations. Agents can safely run /aloop against this epic without being misled by stale docs or forced into unsupported reboot automation.

## Notes

**2026-06-15T14:01:00Z**

Prepared repo for long /aloop operation. Active guidance is now docs/oneplus-agent-loop.md and concise docs/oneplus-bringup.md; historical long bring-up notes moved to docs/archive/oneplus-bringup-history-20260615.md. Final sentinel ticket nd-nebp should close the epic only after a final scan finds no actionable work.
