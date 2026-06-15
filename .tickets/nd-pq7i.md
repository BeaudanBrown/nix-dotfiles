---
id: nd-pq7i
status: closed
deps: [nd-qo2o]
links: []
created: 2026-06-15T13:54:54Z
type: bug
priority: 2
assignee: Beaudan Brown
parent: nd-8dw3
tags: [oneplus, battery, upower, hardware]
---
# Investigate battery fuel gauge metadata

bq27xxx battery driver reports missing/invalid energy-full-design metadata.

## Design

Check UPower and /sys/class/power_supply capacity/design reporting. Determine whether the warning is cosmetic or affects capacity/percentage. If fix requires device-tree/kernel work, flag and close/split as blocked-by-kernel-work.

## Acceptance Criteria

Battery reporting impact is categorized. A config/data fix is applied if possible, or a precise follow-up ticket captures required kernel/DT work.

## Notes

**2026-06-15T14:30:07Z**

Battery metadata categorized as cosmetic/non-blocking on current boot. Evidence: /sys/class/power_supply/bq27411-0 exposes capacity=63, charge_full_design=3640000, charge_full=2993000, charge_now=2076000, voltage/current/temp; UPower exposes battery_bq27411_0 with 63%, time-to-full, energy-full-design=16.016 Wh, energy-full=13.1736 Wh, voltage/rate; retained current kernel journal has no bq27xxx/energy-full-design warning. Updated docs/oneplus-bringup.md with current summary; no Nix/userspace fix or follow-up needed unless fields disappear in a future boot.

**2026-06-15T14:30:07Z**

HANDOFF: categorized OnePlus bq27xxx energy-full-design warning as cosmetic historical DT/property probing noise; docs/oneplus-bringup.md now records usable sysfs and UPower battery metadata; verification ran sysfs/UPower/journal checks plus doc grep; remaining risk is only future regression if percentage/charge fields disappear.
