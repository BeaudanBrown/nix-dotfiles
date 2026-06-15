# OnePlus 6T Bring-up Current State

This is the short, current entry point for agents working on the `oneplus` / OnePlus 6T (`fajita`) host.

Do **not** treat old debugging transcripts or generation-by-generation audio notes as the active task list. The active backlog is the tk epic:

- `nd-8dw3` — OnePlus issue-loop stabilization backlog

Run `tk show nd-8dw3`, then work ready child tickets with `/aloop` or `tk ready`. If investigation discovers new concrete work, create/link tk tickets and keep the epic moving.

Historical bring-up notes were moved to:

- `docs/archive/oneplus-bringup-history-20260615.md`

Use the archive only as evidence when needed. If you find useful facts there, copy the concise current conclusion into the relevant tk ticket or this file instead of sending future agents back through the whole history.

## Operating rules for loop agents

1. Start from tk, not from archived logs.
2. Read the selected ticket, this file, `docs/oneplus-agent-loop.md`, and only the source files needed for that ticket.
3. Inspect current runtime/log state before assuming an old journal line is still true.
4. Make focused changes; create follow-up tickets for new discoveries instead of silently expanding scope.
5. If progress requires a kernel rebuild, kernel patching, or a new kernel closure, record the blocker in tk, create/link a kernel-work ticket if useful, close the current non-kernel ticket as blocked by kernel work, and move on. Do not build kernels in normal `/aloop`.
6. If reboot validation is needed, commit coherent changes, seed `.pi/boot-task.md`, run `nr` only when appropriate, then either stop for manual reboot or, on OnePlus only, use the constrained single `sudo -n /run/current-system/sw/bin/reboot` handoff approved by `nd-pcdw`.

## Current known-good state

- Host: `oneplus`, board: OnePlus 6T / `fajita`, roots: `minimal`, `common`, `network`, `client`.
- Temporary debug sudo is enabled for `wheel` on this host. Remove it after the phone is stable.
- The OnePlus-specific `nr` path builds a boot generation and sets it as the next boot. Do not run `nix eval` immediately before `nr`.
- Speaker playback is expected through the custom speaker-only UCM/ACP path.
- `oneplus-audio-route.service` initializes the speaker route before WirePlumber.
- `oneplus-mic-source.service` exists but is intentionally manual-only.
- SysRq-backed `reboot` and `shutdown` wrappers exist. `nd-pcdw` validated one clean `sudo -n /run/current-system/sw/bin/reboot` handoff, so single-ticket boot validation may use that exact path after seeding `.pi/boot-task.md`; repeated unattended reboot loops remain unapproved.

## GPU/display current summary

The current boot has the expected `msm_dpu` DRM device and GUI output. The old `a630_sqe.fw` / `a630_gmu.bin` lookup warnings are classified as harmless firmware-location noise: the firmware exists in the current compressed firmware tree (`qcom/a630_sqe.fw.zst`, `qcom/a630_gmu.bin.zst`) and the driver later logs that both files loaded from the new location. Current dmesg still shows early `arm-smmu 15000000.iommu: Unhandled context fault` lines and a separate burst of `msm_dpu` vblank/ppdone timeout warnings; track the latter under `nd-843d` if it correlates with display instability. Do not chase kernel/device-tree fixes in normal `/aloop`.

## Wi-Fi current summary

Wi-Fi is functional on the current boot despite the older `ath10k_snoc` warning cluster. On 2026-06-16 the phone was connected to the local SSID on `wlan0`, had an IPv4 default route, and successfully pinged the gateway with 0% packet loss.

The random-MAC cause is now identified: the upstream OnePlus 6T device tree enables WCN3990 but does not provide a MAC/calibration nvmem binding, while the Android `persist` partition contains `/wlan_mac.bin` with interface MAC assignments. The live `wlan0` address had `addr_assign_type=3` (`NET_ADDR_RANDOM`) and did not match the persistent `Intf0MacAddress` entry, so Linux is not consuming that file today.

No `ath10k` key install/remove timeout was present in the current boot journal or retained kernel journals during this check. Treat the old key warnings as historical/noisy unless they recur with disconnects, roaming failures, or WPA rekey failures.

## Bluetooth current summary

Current boot exposes the WCN3990 Bluetooth controller as `/sys/class/bluetooth/hci0`, and no current kernel log line matches the old `pwrseq-qcom_wcn wcn3990-pmu` / SPMI `-EPERM` failure cluster. The remaining userspace failure was configuration: the `oneplus` host has only `minimal`, `common`, `network`, and `client` roots, so it did not import the work-root Bluetooth module and had no `bluetooth.service` or `bluetoothctl`. The host now enables `hardware.bluetooth` directly; validate adapter listing after the next boot/switch.

## Touch and terminal-scroll current summary

Raw touchscreen swipes reach evdev/lisgd on the OnePlus touch device, but Ghostty/tmux does not currently translate direct finger swipes into wheel escape bytes. The host has a narrow workaround in `hosts/oneplus/oneplus-fajita/ui/niri.nix`: central one-finger up/down lisgd gestures run `oneplus-terminal-scroll`, which first confirms the focused niri window is Ghostty and then scrolls the most recently active tmux client/pane, falling back to PageUp/PageDown for non-tmux Ghostty. The script no-ops for non-Ghostty focus so normal touch use outside terminals is not globally remapped.

## Battery current summary

Battery reporting is usable on the current boot. `/sys/class/power_supply/bq27411-0` exposes percentage and charge metadata (`capacity=63`, `charge_full_design=3640000`, `charge_full=2993000`, `charge_now=2076000` during the 2026-06-16 check), while UPower reports the same battery with percentage, time-to-full, voltage, rate, design energy, and current full energy. The old `bq27xxx-battery ... missing/invalid battery:energy-full-design-microwatt-hours` lines were not present in retained current kernel journals; treat them as cosmetic DT/property probing noise unless percentage or charge/energy fields disappear in a future boot.

## Camera current summary

Current boot separates the camera sensor path from the actuator/OIS path. The CAMSS media device and capture video nodes exist, and the three known camera sensors bind as V4L2 subdevices: `imx371 16-0010`, `imx519 16-001a`, and `imx376 17-0010`. The two OIS/actuator chips also bind as subdevices (`lc898217xc 16-0072` and `lc898217xc 17-0074`). The old `lc898217xc ... Error writing reg 0x0084: -6` / `failed to set DAC: -6` lines were not present in the retained current kernel journal during the 2026-06-16 check, so treat them as historical unless they recur during focus/OIS movement or camera open tests.

The host now includes `v4l-utils` and `libcamera` so future on-device checks can inspect the media graph and attempt sensor capture separately from actuator/OIS behavior. If actuator DAC writes recur while sensors still enumerate/capture, the likely remaining seam is kernel driver/device-tree power sequencing/regulator work, not a Nix userspace service.

## RTC/time current summary

The PMIC RTC is still not a trustworthy wall-clock source: on 2026-06-16 `timedatectl` showed synchronized system time but `RTC time: Fri 1970-01-02 00:36:21`, and `/sys/class/rtc/rtc0/name` was `rtc-pm8xxx c440000.spmi:pmic@0:rtc@6000`. The same boot initially synchronized through `systemd-timesyncd` about two minutes after `systemd-timesyncd` start; early services such as NetworkManager retained 1970-era activation timestamps until the network clock step.

Mitigation is host-local and non-kernel: `oneplus-time-save.timer` periodically touches `/var/lib/oneplus-time-seed/stamp`, and `oneplus-time-restore.service` restores that saved timestamp early in the next boot if the current clock is older. This does not fix the PMIC RTC itself, but it prevents certificate/timer consumers from seeing 1970 after the first seeded runtime. `tailscaled.service` is ordered after `time-sync.target` on OnePlus so its control-plane TLS/auth path waits for real NTP when possible. A true RTC persistence fix remains kernel/DT/firmware work and should not be pursued in normal `/aloop`.

## Audio and microphone current summary

Speaker playback is the stable audio path. The active direction is:

- keep UCM speaker-only for ACP/PipeWire speaker stability;
- do **not** reintroduce the previous UCM `Mic1` capture/duplex device unless a future ticket overturns current evidence;
- do **not** use a static PipeWire context source for `hw:O6T,1`; it previously risked aborting PipeWire startup;
- expose the bottom mic only through deliberate/manual route setup plus `module-alsa-source` experiments;
- record traceable mic experiments with `nix run .#oneplus-mic-trial` when appropriate.

Important current evidence:

- Generation 70 with speaker-only UCM produced non-zero direct bottom-mic capture.
- Same-boot repeat stayed non-zero.
- A live app-source test on generation 70 worked after manually programming the proven raw ALSA route and loading `module-alsa-source` as `oneplus_bottom_mic`.
- Generation 71 boot-time app-source loading produced the desired app-visible shape but exact-zero capture.
- Generation 72 disabled automatic app-source loading again, but traceable trials still recorded exact-zero after manual route/full poweroff.
- Current conclusion: the safe userspace shape is speaker-only UCM plus manual `module-alsa-source` only after a known-good direct capture state. The remaining exact-zero vs non-zero failure is below UCM/PipeWire and likely needs kernel/ADSP/AFE/SLIM/codec reset or initialization work.

Audio codec/topology warning triage from current boot (`nd-fuc6`):

- `wcd934x-codec ... ASoC: mux ... has no paths` appears during codec registration for unused internal RX mixers and unused TX9/TX10/TX11/TX13 controls. The proven/interesting mic routes use TX7/TX6/TX0, so this is harmless topology inventory noise for current speaker and bottom-mic work.
- `qcom-soundwire ... din-ports (2) mismatch with controller (6)` is a device-tree/kernel SoundWire topology mismatch. Current speaker playback does not depend on fixing it, and the analog bottom-mic route is SLIM/AFE based rather than SoundWire DIN based. Treat it as not actionable unless a future headset/SoundWire path ticket needs it.
- The one-shot `qcom,slim-ngd-ctrl ... QMI wait timeout` is lower-level SLIM/QMI noise. The controller subsequently registers and emits SLIM SAT events, and historical non-zero bottom-mic captures occurred with the same class of boot noise. Keep it as context for `nd-hr89`, not as a separate userspace/UCM fix.
- `MultiMedia1: ASoC: no backend DAIs enabled for MultiMedia1` occurs during early/probe-time PCM use before or outside the intended UCM route. Current PipeWire selects the speaker UCM sink and speaker playback remains the stable path, so do not change UCM for this warning alone. If it recurs during actual playback failures, investigate under a new playback-specific ticket.

Active/split tickets:

- `nd-87m2` — Stabilize OnePlus mic/audio capture path; split after userspace evidence showed the remaining blocker is lower-level.
- `nd-hr89` — investigate OnePlus bottom-mic exact-zero capture despite active ALSA/DAPM route (kernel/ADSP follow-up). Include the SLIM/QMI boot timeout only as background evidence, not as a proven root cause.

Detailed historical trial records are under `docs/oneplus-audio-trials/`. Treat them as evidence, not as current instructions.

## Active issue tickets

Initial journal-derived tickets:

- `nd-zu8n` — Fix hexagonrpcd unit `ConditionPathExists` placement
- `nd-87m2` — Stabilize OnePlus mic/audio capture path
- `nd-o9qo` — Investigate Bluetooth WCN3990 power sequencing failure
- `nd-bcqi` — Investigate Wi-Fi random MAC and key-install warnings
- `nd-jiqb` — Investigate RTC and boot-time clock problems
- `nd-pq7i` — Investigate battery fuel gauge metadata
- `nd-y6z0` — Investigate camera actuator and OIS I2C errors
- `nd-3wfg` — Triage GPU/display firmware and SMMU warnings
- `nd-fuc6` — Triage audio codec topology warnings separately from mic capture
- `nd-24hg` — Investigate touch scrolling in Ghostty/tmux
- `nd-wzyq` — Add OnePlus terminal touch-scroll workaround
- `nd-pcdw` — Validate OnePlus SysRq reboot wrappers before automated reboot loops (closed after one clean constrained handoff)

A final sentinel ticket should remain blocked until the backlog is otherwise exhausted. When it becomes ready, the worker should scan for current unresolved OnePlus hardware/configuration issues. If more work exists, create tickets and make the sentinel depend on them. If no actionable work remains, close the sentinel and the epic with a clear no-more-work note.

## Useful commands

```sh
# Ticket state
tk show nd-8dw3
tk ready
tk blocked

# Current boot/runtime identity
git status --short
git log --oneline -n 10
bootctl status
readlink -f /run/current-system

# Audio state
wpctl status
pactl get-default-sink
pactl get-default-source
pactl list sinks short
pactl list sources short
pactl list cards short
alsaucm -c O6T dump text

# Traceable mic trial, when a ticket explicitly calls for it
nix run .#oneplus-mic-trial -- --mode pmos-runtime --label <short-label> --reset-note '<what reset/runtime state was tested>' --commit
```

## Documentation policy

Keep this file short. Put durable task state in tk tickets. Put large raw experiment outputs in generated artifacts or specific trial records. If a future agent needs a historical detail, it can inspect `docs/archive/oneplus-bringup-history-20260615.md` or git history and then copy only the current conclusion back into tk/current docs.
