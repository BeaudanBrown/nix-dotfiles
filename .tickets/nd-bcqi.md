---
id: nd-bcqi
status: open
deps: [nd-qo2o]
links: []
created: 2026-06-15T13:54:54Z
type: bug
priority: 2
assignee: Beaudan Brown
parent: nd-8dw3
tags: [oneplus, wifi, ath10k, hardware]
---
# Investigate Wi-Fi random MAC and key-install warnings

ath10k_snoc reports invalid MAC address/random MAC and key install/remove timeouts.

## Design

Evidence: invalid MAC address choosing random; failed to install key -110; failed to remove key -110. Determine whether Wi-Fi is functionally stable, where persistent MAC should come from, and whether calibration/NVRAM/firmware data is missing. If resolution requires kernel rebuild, flag and move on.

## Acceptance Criteria

Functional Wi-Fi impact is documented. Persistent MAC source is identified or follow-up ticket created. Any key-install warning impact is categorized as harmless/noisy or actionable.
