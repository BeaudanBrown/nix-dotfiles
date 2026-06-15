---
id: nd-fuc6
status: open
deps: [nd-qo2o, nd-87m2]
links: []
created: 2026-06-15T13:54:54Z
type: task
priority: 2
assignee: Beaudan Brown
parent: nd-8dw3
tags: [oneplus, audio, codec, hardware]
---
# Triage audio codec topology warnings separately from mic capture

Audio logs include wcd934x/ASoC mux no paths, qcom-soundwire DIN mismatch, qcom slim QMI timeout, and no backend DAI warnings.

## Design

Distinguish harmless topology noise from warnings relevant to mic capture. Link findings to the mic ticket where relevant. Avoid changing working speaker path without evidence. If kernel rebuild is required to resolve a warning, flag it and move on.

## Acceptance Criteria

Each warning class is categorized as harmless, related to mic ticket, or requiring a follow-up/blocker. Documentation/ticket notes capture final interpretation.
