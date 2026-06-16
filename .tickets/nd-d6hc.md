---
id: nd-d6hc
status: open
deps: [nd-ihy2, nd-y7b7]
links: [nd-qbd8]
created: 2026-06-16T10:54:43Z
type: task
priority: 3
assignee: Beaudan Brown
parent: nd-gv62
tags: [oneplus, bluetooth, current]
---
# Classify missing OnePlus Bluetooth controller

Current runtime scan on nd-qbd8 found bluetooth.service active but bluetoothctl reports no default controller and KDE Connect repeatedly logs missing BlueZ adapter. Determine whether the OnePlus Bluetooth controller is expected to work on this kernel/config, and either fix a small config/runtime issue or document/block on kernel/firmware evidence.

## Design

Use current boot evidence only: bluetooth.service state, bluetoothctl show/list, rfkill, relevant kernel logs for hci/qca/wcn/uart/firmware, and host config. Avoid broad kernel work unless evidence clearly requires it; if kernel/firmware work is required, record the blocker and keep default config stable.

## Acceptance Criteria

Current Bluetooth controller state is recorded with commands/evidence; if a small Nix/runtime config fix is available it is implemented and validated, otherwise the limitation is documented in tk/docs with a clear blocker/follow-up. The sentinel remains blocked until this is classified.
