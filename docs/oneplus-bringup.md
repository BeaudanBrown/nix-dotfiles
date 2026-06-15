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
6. If reboot validation is needed, commit coherent changes, seed `.pi/boot-task.md`, run `nr` only when appropriate, then stop for manual reboot unless `nd-pcdw` has explicitly approved automated reboot loops.

## Current known-good state

- Host: `oneplus`, board: OnePlus 6T / `fajita`, roots: `minimal`, `common`, `network`, `client`.
- Temporary debug sudo is enabled for `wheel` on this host. Remove it after the phone is stable.
- The OnePlus-specific `nr` path builds a boot generation and sets it as the next boot. Do not run `nix eval` immediately before `nr`.
- Speaker playback is expected through the custom speaker-only UCM/ACP path.
- `oneplus-audio-route.service` initializes the speaker route before WirePlumber.
- `oneplus-mic-source.service` exists but is intentionally manual-only.
- SysRq-backed `reboot` and `shutdown` wrappers exist, but unattended reboot loops are not approved until `nd-pcdw` validates them.

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

Active ticket:

- `nd-87m2` — Stabilize OnePlus mic/audio capture path

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
- `nd-pcdw` — Validate OnePlus SysRq reboot wrappers before automated reboot loops

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
