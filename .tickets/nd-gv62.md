---
id: nd-gv62
status: open
deps: []
links: []
created: 2026-06-16T00:57:55Z
type: epic
priority: 2
assignee: Beaudan Brown
tags: [oneplus, agent-loop, stabilization, current]
---
# OnePlus fresh-agent hardware stabilization loop

Current-source-of-truth epic for fresh agents iterating on the OnePlus host. Agents start from docs/oneplus-loop-bootstrap.md, pick one ready child ticket, assess current runtime and previous git/tk state, make one focused change, record evidence, and either seed a one-shot reboot handoff or leave a clear next inquiry.

## Design

Keep this epic focused on current work. Superseded tickets and old debug records are archived for evidence only. Durable current state belongs in docs/oneplus-bringup.md, reusable procedure/tooling in docs/oneplus-agent-loop.md and docs/oneplus-debug-tools.md, and active work in this epic's child tickets.

## Acceptance Criteria

Fresh agents can start from the bootstrap prompt, discover current ready work without stale ticket noise, iterate one focused OnePlus fix at a time, promote reusable scripts into Nix-wrapped tools, and stop when the sentinel records that no actionable work remains.


## Notes

**2026-06-16T01:01:41Z**

BOOTSTRAP CLEANUP: created current fresh-agent loop docs, moved superseded OnePlus tickets/debug records out of active .tickets/current docs into docs/archive, reset boot-resume seed, and left current work under nd-gv62 only. Fresh agents should start from docs/oneplus-loop-bootstrap.md; next suggested inquiry is either nd-qbd8 current runtime scan or a focused ready child ticket.

**2026-06-16T01:07:19Z**

GIT POLICY UPDATE: removed oneplus-mic-trial auto-commit behavior (--commit now errors) and documented that agents must review diffs and manually create/amend/squash focused commits. Next cleanup before more loop work should be history surgery on the existing noisy commits, done only with explicit rewrite/push guidance.

**2026-06-16T02:03:16Z**

ORDERING UPDATE: top-level loop work is intentionally dependency-gated so /aloop picks up the previous iteration cleanly: nd-qbd8 current scan first, then nd-6g7r display classification, then nd-qa6a patchable kernel flow, then nd-ihy2 mic tracing, then nd-y7lt sentinel. Future agents should add new tickets into this chain by dependency, not by relying only on prose.

**2026-06-16T02:20:09Z**

TOOL LIBRARY UPDATE: added closed child nd-1jlj for OnePlus agent UI observe/control tools. Future agents should extend docs/oneplus-debug-tools.md and the flake-wrapped scripts rather than creating ad-hoc screenshot/touch snippets.

**2026-06-16T10:55:03Z**

HANDOFF from nd-qbd8: current scan found no failed units and no current display/DRM/GPU kernel warnings in focused grep; existing display->kernel->mic chain remains next, and new Bluetooth controller classification ticket nd-d6hc was added after nd-ihy2 before sentinel nd-y7lt.

**2026-06-16T11:52:27Z**

QUEUE UPDATE: user cancelled nd-qa6a patchable-kernel work. Current OnePlus audio focus is non-kernel exploration to get consistent positive speaker and microphone readings; nd-ihy2 is unblocked and should avoid kernel builds/patches.

**2026-06-16T12:20:18Z**

MIC QUEUE UPDATE: added a non-kernel microphone exploration chain before Bluetooth: nd-iwoo measurement validation -> nd-h6lz ALSA/PipeWire matrix -> nd-zthm mixer controls -> nd-vnpn UCM/vendor route comparison -> nd-296h service ordering -> nd-ts1j firmware/DSP runtime logs -> nd-y7b7 fallback input options. nd-d6hc now waits for this sweep; nd-y7lt blocks on all new actionable mic tickets.

**2026-06-16T12:27:30Z**

HANDOFF from nd-iwoo: OnePlus bottom-mic exact-zero was reproduced across helper, direct ALSA, and direct PipeWire capture/analysis paths; docs/oneplus-audio-readings.md now records commands and evidence. nd-h6lz can proceed with ALSA/PipeWire matrix work without first debugging the measurement helper.

**2026-06-16T12:32:56Z**

HANDOFF from nd-h6lz: current ALSA/PipeWire endpoint matrix found no non-zero internal mic source; only MultiMedia2/hw:0,1 opens and remains exact-zero through ALSA and transient PipeWire, so continue the non-kernel chain with nd-zthm mixer-control audit.

**2026-06-16T12:38:24Z**

HANDOFF from nd-zthm: mixer audit found high-gain ADC4 TX7/TX0 deltas can produce non-zero ALSA samples while speaker playback stays positive; conservative helper route remains exact-zero, so nd-vnpn should compare UCM/vendor routes with those gain/selector clues rather than more endpoint enumeration.

**2026-06-16T12:45:16Z**

HANDOFF from nd-vnpn: current UCM has no mic capture device; Oxygen maps bottom builtin_mic_1 to TX0/DEC0/ADC4 and dual TX7/TX8 ADC4+ADC3 routes, which produced only low/noise-like non-zero samples in bounded runtime trials. nd-296h should test service/PipeWire module ordering before any persistent high-gain UCM change.

**2026-06-16T12:52:34Z**

HANDOFF from nd-296h: current-runtime audio service ordering does not recover OnePlus bottom-mic samples; manual app-visible source remains exact-zero while speaker playback survives. nd-ts1j firmware/DSP runtime log inspection is next.

**2026-06-16T12:59:01Z**

HANDOFF from nd-ts1j: firmware/DSP log sweep found no userspace-remediable missing-firmware, remoteproc crash, or audio service failure; exact-zero mic persists while capture attempts correlate with SLIM/WCD TX timeout/overflow logs. Continue to nd-y7b7 fallback input options, not kernel builds.

**2026-06-16T13:03:01Z**

HANDOFF from nd-y7b7: fallback matrix recorded; internal mic remains blocked, recommended practical fallback is USB-C class-compliant mic/headset adapter; Bluetooth fallback should wait for nd-d6hc controller classification.

**2026-06-24T09:13:47Z**

GNSS handoff 2026-06-24: LOC still reachable after reboot/switch and XTRA injection succeeds, but oneplus-gps-watch reports engine-state off(2), no SV/GSV, no valid RMC/GGA. DMS remains offline/HW restricted no, --dms-set-operating-mode=online returns DeviceNotReady, NAS detached, UIM no-ATR. Found active tqftpserv firmware base issue: upstream /lib/firmware does not exist on this NixOS host; current firmware_class path is /run/current-system/firmware. Patched tqftpserv override to use /run/current-system/firmware, preserve nested Android modem_pr/mcfg paths under OnePlus/fajita/enchilada before basename fallback, and add GNSS RFS symlink-shaped readonly/readwrite/shared paths. Switched live and confirmed patched tqftpserv running, but boot-time modem requests require reboot to validate. Avoid /dev/wwan0at* and ipa probing.

**2026-06-24T09:14:30Z**

GNSS live post-switch check: patched tqftpserv restarted at runtime and binary strings confirm /run/current-system/firmware plus OnePlus/fajita and GNSS RFS paths. Live DMS remains offline and set-online still returns DeviceNotReady; oneplus-gps-watch after XTRA still reports engine-state off(2). Extra safe QMI checks: SAR RF state returned 0, DMS power external-source/battery 0, WDS disconnected/rates 0, DSD RAT unknown, UIM slots present/active but no ATR. IPA platform device is present but unbound; no rmnet/net port exists, only wwan0 AT ports. Next required validation is reboot into patched tqftpserv so modem boot-time TFTP/RFS requests use the corrected firmware base/path mapping.

**2026-06-24T13:36:29Z**

GNSS reboot validation 2026-06-24: user rebooted, but host came up on old generation /nix/store/1n13... with old tqftpserv /nix/store/dbrn... so corrected /run/current-system/firmware tqftpserv path was NOT tested at boot. Reboot evidence: boot id f4145c9d..., tqftp/rmtfs active, DMS still offline, UIM no-ATR, LOC config unchanged. Ran nr after discovering this; /nix/var/nix/profiles/system now points to /nix/store/v9jbb41... and its tqftpserv ExecStart is patched /nix/store/zir40... Need one more reboot to validate modem boot-time TFTP/RFS behavior with corrected tqftpserv.

**2026-06-24T13:49:37Z**

GNSS patched-boot validation 2026-06-24: boot id cc71a056, current system /nix/store/v9jbb41, tqftpserv /nix/store/zir40 with /run/current-system/firmware and GNSS RFS path strings confirmed active from boot. No improvement: DMS offline/HW restricted no, set-online DeviceNotReady, DMS bands none, NAS detached/radio none, UIM no-ATR, IPA platform remains unbound/no rmnet net port, LOC config ok but oneplus-gps-watch after init+XTRA still engine-state off(2), 0 valid RMC/GGA/GSV. /var/lib/tqftpserv unchanged. Tried safe UIM SIM power-cycle; returned to no-ATR and did not affect DMS. Tried DMS service reset; no change. PDC list showed all software configs inactive; ROW_Commercial activation hung and left Pending with no immediate DMS/band improvement, then was deactivated back to Inactive. Current leading suspects are missing/unsafe IPA/rmnet/data-port bring-up or deeper modem/RF/NV readiness, not LOC/XTRA/tqftp simple paths.

**2026-06-25T13:21:02Z**

Set up local OnePlus/SDM845 source workspace at /home/beau/src/oneplus-debug outside the dotfiles repo. Shallow clones include sdm845-mainline linux, firmware-oneplus-sdm845, tqftpserv, rmtfs, qrtr, libqmi, ModemManager, Lineage fajita and sdm845-common device trees, Lineage OnePlus SDM845 kernel, AOSP hardware/qcom/gps, and pmaports. Added docs/oneplus-source-workspace.md with search commands, update instructions, and live-debug safety reminders; linked it from docs/oneplus-bringup.md.

**2026-06-25T13:40:58Z**

New lead from source/live exploration: DMS --get-capabilities returns Max TX/RX 0 and empty Networks, suggesting modem stack is not just carrier/IMEI-blocked. Found firmware/NV mismatch: NixOS prepackaged sdm845-mainline firmware currently boots modem image MPSS...1.358880.1.399256.2, while the phone's mounted modem_a/verinfo is MPSS...1.276740.1.331501.2. Prepared /home/beau/src/oneplus-debug/oneplus-stock-firmware by copying modem_a and using /home/beau/src/oneplus-debug/pil-squasher to create modem/adsp/cdsp/slpi .mbn from .mdt+.bXX. Added environment-gated stock firmware overlay in hosts/oneplus/oneplus-fajita/hardware/sdm845.nix: normal pure eval unchanged; to test, set ONEPLUS_STOCK_FIRMWARE_STORE=/nix/store/slb6brqn44cgcv8by5vdc4yw9divkmfn-oneplus-stock-firmware and run rebuild/eval with --impure, then reboot and re-check DMS bands/UIM/LOC engine. Pure and impure drvPath evals both succeeded.

**2026-06-25T13:52:11Z**

Stock firmware experiment switched and ready for reboot. Ran sudo env ONEPLUS_STOCK_FIRMWARE_STORE=/nix/store/slb6brqn44cgcv8by5vdc4yw9divkmfn-oneplus-stock-firmware nixos-rebuild switch --flake .#oneplus --impure. New current generation /nix/store/z3rpy20ljk1ia64ywg0wva7bgp71n5an-nixos-system-oneplus-26.05.20260531.b51242d. /run/current-system firmware now stages stock-derived modem string MPSS...1.331501.2.358880.1 / MPSS.AT.4.0_276740. Remoteprocs are still running old booted images until reboot. Next: reboot, then verify DMS revision/capabilities/bands/operating-mode, UIM slot, and LOC engine after XTRA.

**2026-06-25T13:59:17Z**

Stock firmware post-reboot test complete, boot id 87dde34f. Booted generation /nix/store/z3rpy20 with phone-local stock-derived firmware. Kernel logs confirm ADSP/CDSP/SLPI stock-derived sizes (adsp 11128744, cdsp 2831892, slpi 6881468) and modem MBA size 242400 loaded; DMS revision changed to MPSS...1.331501.2.358880.1 [Dec 17 2020]. No functional improvement: DMS capabilities still TX/RX 0 and Networks empty; bands none; operating mode offline HW restricted no; set-online DeviceNotReady; NAS not registered radio none; UIM both slots no-atr-received; LOC init/XTRA still works but oneplus-gps-watch 180s stays engine-state off(2), no GSV/fix. Firmware package mismatch is now lower probability. Next likely directions: SIM/UIM electrical/pinctrl/regulator path, deeper modem NV/RFS write/readiness despite rmtfs -r, or IPA/rmnet/DPM readiness, but avoid live IPA load and AT probing.

**2026-06-25T21:22:52Z**

Continued post-stock-firmware debugging. Found useful data-port fact: postmarketOS-style DPM open works over QRTR with hw-data-ep-type=embedded,hw-data-ep-iface-number=1,hw-data-rx-id=2,hw-data-tx-id=10. WDA get/set works when scoped to ep-type=embedded,ep-iface-number=1; set raw-ip + qmap succeeds. This does not load IPA and does not touch AT ports. No improvement after DPM/WDA: no rmnet netdev because IPA remains unbound; DMS still offline/DeviceNotReady; WDA unscoped get still InvalidArgument; LOC still engine-state off(2). Added oneplus-modem-data-init helper to hosts/oneplus/oneplus-fajita/system.nix and validated it is in oneplus systemPackages via nix eval. Also noted pmaports msm-modem-uim-selection requires Card state present + USIM AID, but our UIM card status remains no-atr-received with no app/AID, so that script would not help yet. Next likely directions: safe source/DTS analysis for why UIM no ATR and whether IPA can be boot-probed safely; consider rmtfs writable only as an explicit higher-risk boot experiment.

**2026-06-26T01:02:23Z**

Continued focused debugging on UIM/SIM and rmtfs. UIM: live TLMM debugfs shows UIM2 data/clk/reset GPIO105-107 and UIM1 data/clk/reset GPIO109-111 are muxed as func0 GPIO outputs low; only UIM2_PRESENT GPIO108 and UIM1_PRESENT GPIO112 are func1/pulled up. qmicli UIM switch-slot/power-cycle did not produce ATR; after restoring physical slot 1 active, card status remains no-atr-received. pmaports msm-modem-uim-selection requires Card state present + USIM AID, absent here, so provisioning-session selection is not actionable yet. This points to SIM electrical/pinctrl/regulator or modem-side pin setup, not just UIM userspace. RMTFS: inspected rmtfs source; -r read-only mode populates shadow buffers and accepts writes into memory, so it should not block same-boot modem writes, but can hide persistence across reboot. Staged rmtfs ExecStart with -v in qualcomm-services.nix for next boot logging; did not live-restart rmtfs. Eval confirms ExecStart includes -r -P -s -v.

**2026-06-26T01:55:56Z**

Rebuilt/switch after staging rmtfs -v and oneplus-modem-data-init. New generation /nix/store/ny6zm4d6xi2a4fj0mj58z9scy9d5sa5n-nixos-system-oneplus-26.05.20260531.b51242d. systemd did not restart rmtfs, as intended (restartIfChanged=false); next reboot needed for verbose rmtfs logging at modem boot. ExecStart now shows rmtfs -r -P -s -v. oneplus-modem-data-init is installed and a run of it again opened DPM and set WDA raw-ip/qmap on embedded endpoint 1 successfully. This pure rebuild stages normal prepackaged modem firmware again (MPSS...1.399256.2) for next boot; stock firmware mismatch was already negative.

**2026-06-26T02:12:48Z**

After reboot into generation /nix/store/ny6zm4d6xi2a4fj0mj58z9scy9d5sa5n-nixos-system-oneplus-26.05.20260531.b51242d (boot a0fd0cc3-154a-40b5-b85a-e868ee151e6c), rmtfs is running with ExecStart rmtfs -r -P -s -v, but journal only contains service start. Source check shows verbose dbgprintf uses vprintf without flushing; under systemd stdout is block-buffered, so boot-time request lines may be hidden. Post-boot status unchanged: DMS offline/HW restricted no; --dms-set-operating-mode=online returns DeviceNotReady; capabilities still TX/RX 0 and networks empty; UIM slots present but no-atr-received, after this boot both physical slots reported active/logical 1+2; LOC watch still emits NMEA with engine-state off(2). Running oneplus-modem-data-init succeeds for DPM/WDA embedded endpoint 1 but DMS remains offline. Staged next patch in qualcomm-services.nix: rmtfs override substitutes vprintf(fmt, ap); with vprintf(fmt, ap); fflush(stdout); so next rebuild/boot should expose verbose rmtfs lines without live restart.
