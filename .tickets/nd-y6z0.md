---
id: nd-y6z0
status: open
deps: [nd-qo2o]
links: []
created: 2026-06-15T13:54:54Z
type: bug
priority: 2
assignee: Beaudan Brown
parent: nd-8dw3
tags: [oneplus, camera, ois, hardware]
---
# Investigate camera actuator and OIS I2C errors

lc898217xc camera actuator/OIS reports I2C register write and DAC failures.

## Design

Check camera enumeration/capture separately from actuator/OIS. Determine whether errors come from power sequencing, regulator, driver expectations, or missing userspace. Split sensor vs actuator tickets if needed. If progress requires kernel rebuild, flag and move on.

## Acceptance Criteria

Camera sensor status is separated from actuator/OIS status. A small fix is implemented if available, or follow-up blocker ticket(s) are created with evidence.
