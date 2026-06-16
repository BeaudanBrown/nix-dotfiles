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
