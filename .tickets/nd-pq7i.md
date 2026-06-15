---
id: nd-pq7i
status: open
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
