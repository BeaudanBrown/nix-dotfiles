---
id: nd-jiqb
status: closed
deps: [nd-qo2o]
links: []
created: 2026-06-15T13:54:54Z
type: bug
priority: 2
assignee: Beaudan Brown
parent: nd-8dw3
tags: [oneplus, rtc, time, hardware]
---
# Investigate RTC and boot-time clock problems

rtc-pm8xxx appears to set system clock to 1970 at boot, causing confusing logs and possible certificate/timer issues.

## Design

Inspect current RTC/time-sync behavior, journal timestamps, systemd-timesync/NetworkManager timing, and certificate-sensitive services. Consider mitigation before network time for services that care. If true hardware RTC persistence requires kernel/DT work, flag and split/close appropriately.

## Acceptance Criteria

Current time behavior is documented. A mitigation/fix is implemented if feasible without kernel rebuild, or a focused follow-up/blocker ticket is created.

## Notes

**2026-06-15T14:21:03Z**

HANDOFF: Confirmed live system time syncs via systemd-timesyncd while rtc-pm8xxx still reports 1970; documented current behavior in docs/oneplus-bringup.md; added OnePlus userspace time seed restore/save timer and ordered tailscaled after time-sync.target using systemd-time-wait-sync; validation: nix eval for oneplus systemd units/timer/tailscaled ordering passed; remaining risk: PMIC RTC persistence itself remains kernel/DT/firmware work and first boot after deploying needs a seed to be written.
