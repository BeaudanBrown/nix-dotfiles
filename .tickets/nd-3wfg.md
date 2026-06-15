---
id: nd-3wfg
status: open
deps: [nd-qo2o]
links: []
created: 2026-06-15T13:54:54Z
type: task
priority: 2
assignee: Beaudan Brown
parent: nd-8dw3
tags: [oneplus, gpu, display, firmware]
---
# Triage GPU/display firmware and SMMU warnings

msm_dpu/a630 firmware and arm-smmu warnings appear in logs, though later evidence suggests firmware eventually loads and GUI works.

## Design

Confirm current generation firmware paths and relevant dmesg. Decide whether warnings are harmless/noisy or indicate instability. If a fix would require kernel rebuild, flag and close as blocked/no-action rather than building kernel.

## Acceptance Criteria

Warnings are classified with current evidence. Any needed follow-up ticket is created; otherwise ticket closes as documented-no-action.
