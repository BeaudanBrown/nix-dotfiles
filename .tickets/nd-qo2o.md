---
id: nd-qo2o
status: open
deps: []
links: []
created: 2026-06-15T13:54:53Z
type: task
priority: 2
assignee: Beaudan Brown
parent: nd-8dw3
tags: [oneplus, docs, audio, agent-loop]
---
# Clean OnePlus bring-up docs into current-state plus archive pointers

Make docs/oneplus-bringup.md agent-safe by replacing stale top-level mic/audio directions with current state and pointers to archived trial evidence.

## Design

Add a concise current-state section near the top. Demote or mark historical the long generation-by-generation mic narrative. Preserve evidence via links to docs/oneplus-audio-trials/. Current audio facts to capture: speaker playback is stable through speaker-only UCM/ACP path; UCM Mic1 should not be reintroduced; static PipeWire context source is known risky; oneplus-mic-source.service is manual-only; gen70 got non-zero bottom-mic capture and live app-source, while gen71/72 regressed to exact-zero; next audio work should investigate ADSP/SLIM/codec reset/state and use traceable trials.

## Acceptance Criteria

A fresh agent can read the top of docs/oneplus-bringup.md and know the current OnePlus audio/mic target without chasing obsolete directions. Contradictory historical statements are removed, moved, or explicitly marked historical. Journal issue list points to tk tickets once available.
