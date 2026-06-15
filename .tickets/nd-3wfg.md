---
id: nd-3wfg
status: closed
deps: [nd-qo2o]
links: [nd-843d]
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

## Notes

**2026-06-15T14:09:21Z**

Triage evidence on current oneplus boot /nix/store/sr5cs5ac1j2ah543nrj6fsvcrha5hz71-nixos-system-oneplus-26.05.20260531.b51242d: /run/current-system/firmware points at cpxxb3mm...-firmware and contains qcom/a630_sqe.fw.zst, qcom/a630_gmu.bin.zst, plus qcom/sdm845/OnePlus/fajita/a630_zap.mbn.zst. sudo dmesg shows the old a630 files load successfully later from the new location at ~41s, so classify a630 firmware lookup warnings as harmless/no-action. Current dmesg still has early arm-smmu context faults and separate msm_dpu vblank/ppdone timeout WARNs; created linked follow-up nd-843d for the vblank cluster rather than expanding this triage.

**2026-06-15T14:09:32Z**

HANDOFF: classified current a630 firmware warnings as harmless/no-action because compressed firmware is present and dmesg logs successful new-location loads; documented in docs/oneplus-bringup.md; created linked follow-up nd-843d for current msm_dpu vblank timeout WARN cluster; verification: sudo dmesg firmware/display filter, firmware fd inventory, docs/ticket rg.
