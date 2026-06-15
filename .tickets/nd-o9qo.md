---
id: nd-o9qo
status: open
deps: [nd-qo2o]
links: []
created: 2026-06-15T13:54:54Z
type: bug
priority: 2
assignee: Beaudan Brown
parent: nd-8dw3
tags: [oneplus, bluetooth, wcn3990, hardware]
---
# Investigate Bluetooth WCN3990 power sequencing failure

Bluetooth appears absent with WCN3990/SPMI power sequencing errors and BlueZ adapter not found symptoms.

## Design

Evidence includes disallowed SPMI write to sid=0 addr=0xC240, qcom-spmi-gpio write 0x40 failed, pwrseq-qcom_wcn wcn3990-pmu error -EPERM, BlueZ system service unavailable/no local adapter. Confirm current runtime with bluetoothctl list, relevant services, and journal. Narrow cause to config/service/device-tree/kernel. If kernel rebuild is required, flag and close as blocked-by-kernel-work rather than building kernel in /aloop.

## Acceptance Criteria

Current runtime state is recorded. A small config/service fix is implemented if found; otherwise a precise follow-up/blocker ticket is created with evidence.
