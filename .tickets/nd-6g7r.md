---
id: nd-6g7r
status: open
deps: []
links: []
created: 2026-06-16T00:57:56Z
type: task
priority: 2
assignee: Beaudan Brown
parent: nd-gv62
tags: [oneplus, display, gpu, current]
---
# Classify current OnePlus display stability warnings

Check current display/GPU/DRM health and classify whether any live warnings correlate with user-visible instability.

## Design

Use current dmesg/journal and observed display behavior. Ignore old ticket narratives unless needed as git history. If the issue requires kernel/DT work, record the blocker and create/link a focused kernel ticket rather than building in a normal loop iteration.

## Acceptance Criteria

Current display state is documented in tk/docs. Any low-risk config fix is applied, or the issue is closed/no-action/kernel-work with current evidence.
