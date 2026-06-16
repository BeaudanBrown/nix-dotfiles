---
id: nd-fuc6
status: closed
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

## Notes

**2026-06-15T14:16:36Z**

Current boot triage complete. Evidence: sudo dmesg still shows wcd934x no-path mux lines for RX INT0-4/7 and TX9/10/11/13, qcom-soundwire DIN 2-vs-6 mismatch, one qcom slim-ngd QMI wait timeout followed by SLIM controller/SLIM SAT activity, and one MultiMedia1 no-backend-DAI warning. Classification: wcd934x no-path mux lines are harmless unused topology for current routes; SoundWire DIN mismatch is DT/kernel topology noise not used by current speaker or analog bottom mic; SLIM QMI timeout is only background for nd-hr89 because later SLIM activity and historical non-zero captures prove it is not by itself fatal; MultiMedia1 no-backend warning is early/probe-time noise unless paired with actual playback failure. Updated docs/oneplus-bringup.md; no UCM changes.

**2026-06-15T14:16:36Z**

HANDOFF: categorized OnePlus audio warning classes and documented them in docs/oneplus-bringup.md; verification ran sudo dmesg filtered warning scan, wpctl status, and alsaucm -c O6T dump text; remaining risk is only if no-backend-DAI recurs with actual playback failures, then create a playback-specific ticket.
