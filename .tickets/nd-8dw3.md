---
id: nd-8dw3
status: open
deps: []
links: []
created: 2026-06-15T13:54:53Z
type: epic
priority: 2
assignee: Beaudan Brown
tags: [oneplus, agent-loop, stabilization, mutable-backlog]
---
# OnePlus issue-loop stabilization backlog

Mutable /aloop scaffolding epic for OnePlus stabilization. Turn journal/log findings into concrete tk-backed work, clean stale docs, and let agents iterate by exploring, planning, implementing focused fixes, and creating/linking follow-up tickets as discoveries emerge.

## Design

Treat this epic as the live OnePlus stabilization backlog. Each /aloop worker should read this epic, the selected child ticket, recent notes, git status/log, and relevant docs; inspect current runtime/log/code state enough to confirm the issue; add or link new tickets for discovered sub-issues instead of silently expanding scope; make a focused fix or documentation improvement; record evidence in tk notes and docs where useful; commit coherent code/docs/ticket changes together. Reboot-required work must commit, seed .pi/boot-task.md, run nr only when appropriate, then stop for manual reboot unless a later ticket explicitly proves automated reboot safe. If an issue cannot be pursued further without kernel rebuild/kernel development, record the blocker, create/link a clear kernel-work ticket if useful, close the current ticket as blocked-by-kernel-work, and move on to other ready work rather than building a kernel in /aloop.

## Acceptance Criteria

Known OnePlus journal issues are represented as concrete child tickets with evidence, likely seams, and acceptance criteria. docs/oneplus-bringup.md is cleaned so current state and open issue pointers are not contradicted by old mic/audio history. Reboot-loop limitations are documented for /aloop. Initial actionable tickets exist for simple non-reboot fixes and deeper hardware investigations. Agents can safely run /aloop against this epic without being misled by stale docs or forced into unsupported reboot automation.

## Notes

**2026-06-15T14:01:00Z**

Prepared repo for long /aloop operation. Active guidance is now docs/oneplus-agent-loop.md and concise docs/oneplus-bringup.md; historical long bring-up notes moved to docs/archive/oneplus-bringup-history-20260615.md. Final sentinel ticket nd-nebp should close the epic only after a final scan finds no actionable work.

**2026-06-15T14:06:19Z**

HANDOFF from nd-24hg: touch scrolling is not a raw touchscreen/kernel failure; lisgd sees OnePlus swipes on platform-a90000.i2c-event. Remaining actionable work is follow-up nd-wzyq for a Ghostty/niri/tmux touch-to-scroll workaround.

**2026-06-15T14:09:21Z**

HANDOFF from nd-3wfg: a630 firmware warnings classified as harmless compressed/new-location firmware noise; current boot does show separate msm_dpu vblank timeout WARN cluster, captured as linked follow-up nd-843d and added as a blocker for nd-nebp.

**2026-06-15T14:11:24Z**

HANDOFF from nd-87m2: mic userspace work is split; keep speaker-only UCM, do not reintroduce UCM Mic1 or static PipeWire source. Remaining bottom-mic exact-zero/non-zero issue is tracked by linked child nd-hr89 for kernel/ADSP investigation; nd-nebp now depends on it.

**2026-06-15T14:14:39Z**

HANDOFF from nd-bcqi: OnePlus Wi-Fi is currently functional; persistent MAC source is Android persist /wlan_mac.bin, but mainline DT/driver is not consuming it and wlan0 is random (addr_assign_type=3). No current ath10k key timeout warnings found; treat old key warnings as historical unless they recur with connectivity symptoms.

**2026-06-15T14:16:36Z**

HANDOFF from nd-fuc6: audio codec topology warnings are now categorized in docs/oneplus-bringup.md; no separate follow-up ticket was created. Keep speaker-only UCM; only SLIM/QMI noise remains relevant as background context for nd-hr89.

**2026-06-15T14:21:03Z**

HANDOFF from nd-jiqb: OnePlus RTC still reports 1970 even after NTP sync; non-kernel mitigation now saves/restores /var/lib/oneplus-time-seed/stamp and delays tailscaled until time-sync.target. True RTC persistence remains kernel/DT/firmware work, not normal /aloop scope.

**2026-06-15T14:23:23Z**

HANDOFF from nd-o9qo: current OnePlus Bluetooth issue was a userspace config gap, not a reproduced WCN3990 power-sequencing failure on this boot: hci0 exists and old pwrseq/SPMI -EPERM logs are absent. oneplus now enables hardware.bluetooth directly; validate bluetoothctl list after a future switch/boot.

**2026-06-15T14:25:31Z**

HANDOFF from nd-pcdw: reboot automation is still not approved. nd-pcdw now has a documented one-cycle manual SysRq wrapper validation checklist and .pi/boot-task.md seed; next step is an actual supervised sudo -n /run/current-system/sw/bin/reboot followed by post-boot evidence before any policy change.

**2026-06-15T14:28:03Z**

HANDOFF from nd-pcdw: OnePlus SysRq reboot wrapper had one clean full handoff. Future reboot-required OnePlus tickets may use a single committed/seeded sudo -n /run/current-system/sw/bin/reboot cycle, but no chained reboot loops or automatic nr&&reboot stress cycles are approved.

**2026-06-15T14:30:07Z**

HANDOFF from nd-pq7i: OnePlus battery reporting is usable in current sysfs/UPower; old bq27xxx energy-full-design warnings were absent from retained current kernel logs and are treated as cosmetic unless capacity/charge reporting regresses.

**2026-06-15T14:34:40Z**

HANDOFF from nd-y6z0: OnePlus camera sensors and lc898217xc actuator subdevices enumerate on current boot; old actuator DAC I2C errors did not recur in retained current kernel journal. oneplus now includes v4l-utils/libcamera for future camera graph/capture checks; remaining actuator power-sequencing work should only be ticketed if errors recur during camera-open/focus tests.

**2026-06-15T14:40:00Z**

HANDOFF from nd-wzyq: OnePlus terminal touch-scroll is now handled by a focused Ghostty-only lisgd bridge in hosts/oneplus/oneplus-fajita/ui/niri.nix; next OnePlus switch/boot should test center one-finger swipes in Ghostty/tmux for direction/amount.

**2026-06-15T14:42:28Z**

HANDOFF from nd-hr89: current generation 74/75 bottom-mic trial still exact-zero with ALSA RUNNING/advancing pointers and no dmesg delta. Normal /aloop userspace work is exhausted; kernel-development follow-up nd-n819 now tracks the sdm845/wcd934x/q6afe/slim patch/trace target and blocks nd-nebp.

**2026-06-15T14:45:47Z**

HANDOFF from nd-n819: selected kernel-development ticket cannot progress in normal /aloop because OnePlus currently boots a fetched pinned kernel closure, not a patchable source derivation. Created prerequisite nd-1q85 for an explicit patchable kernel flow; nd-n819 now depends on it and remains the bottom-mic trace/patch target.
