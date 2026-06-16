# OnePlus 6T Current State

This is the current-state entry point for agents working on the `oneplus` host / OnePlus 6T (`fajita`). It should describe what exists now.

Start with:

- `docs/oneplus-loop-bootstrap.md` — fresh-agent seed and work-selection flow
- `docs/oneplus-agent-loop.md` — loop boundaries
- `docs/oneplus-debug-tools.md` — reusable diagnostics
- tk epic `nd-gv62` — current active backlog

Closed tickets, archived bring-up notes, old trial records, and git history are evidence only. If an old result matters, copy the current conclusion into the active ticket or this file.

## Host summary

- Host: `oneplus`
- Board: OnePlus 6T / `fajita`
- Roots: `minimal`, `common`, `network`, `client`
- Temporary bring-up sudo is enabled for `wheel`; remove it when the device is stable.
- The OnePlus `nr` path prepares the next boot generation. Commit coherent changes before `nr` and do not run `nix eval` immediately before it.
- A single ticket-scoped reboot handoff may use `sudo -n /run/current-system/sw/bin/reboot` after `.pi/boot-task.md` is seeded, preferably with `nix run .#oneplus-loop-seed-reboot -- <ticket> --checks "..."`. Repeated unattended reboot loops are not approved.

## Current work selection

Use `tk ready` and choose the next dependency-unblocked child ticket under `nd-gv62`. The queue is intentionally ordered with dependencies so `/aloop` moves forward predictably:

- `nd-qbd8` — scan current runtime and choose/create the next hardware issue; first reset point
- `nd-6g7r` — classify current display stability warnings; depends on `nd-qbd8`
- `nd-qa6a` — provide an opt-in patchable OnePlus kernel experiment flow; depends on `nd-6g7r`
- `nd-ihy2` — trace bottom microphone exact-zero capture; depends on `nd-qa6a`
- `nd-y7lt` — stop sentinel; depends on all actionable work and closes the loop when no actionable work remains

If a new issue is discovered, add it as a focused child ticket and wire it into this dependency chain instead of relying on ticket creation time or prose priority.

The previous backlog and its child tickets are superseded and should not guide new work.

## Runtime areas

### Boot / resume

The graphical OnePlus session starts Ghostty and `scripts/pi-boot-resume.sh`, which attaches to tmux and sends `.pi/boot-system.md` plus `.pi/boot-task.md` and optional `.pi/boot-next-loop.md` into the newest Pi session. These `.pi` task files are untracked and should be rewritten for each reboot validation.

### Networking

NetworkManager/iwd/Tailscale are configured for the host. Agents should validate current connectivity from runtime state rather than relying on old notes.

### Bluetooth

The host enables NixOS Bluetooth support directly because the phone does not import the work-root desktop Bluetooth module. Validate adapter and service state after changes with current runtime commands.

### Display / UI / touch

The current UI stack is Niri/Ghostty with OnePlus-specific startup and gesture helpers. A focused terminal-scroll bridge exists in `hosts/oneplus/oneplus-fajita/ui/niri.nix` and should be validated/tuned from current touch behavior if needed.

Display/GPU warnings should be investigated under current tickets only when they recur or correlate with visible instability. Use current `dmesg`/journal evidence; do not chase historical warning clusters by default.

### Audio / microphone

Speaker playback is the stable supported audio path. The host keeps a conservative userspace shape for audio:

- speaker playback through the OnePlus UCM/ACP path;
- `oneplus-audio-route.service` initializes the speaker route before WirePlumber;
- `oneplus-mic-source.service` is manual-only;
- bottom-mic work should use `docs/oneplus-debug-tools.md` and active tickets.

The current bottom-mic work is kernel/ASoC/ADSP/SLIM/WCD934x focused and should proceed only through the clean current tickets (`nd-qa6a`, then `nd-ihy2`). Do not reintroduce broad UCM/PipeWire microphone changes unless current evidence and the active ticket justify it.

### Camera / battery / RTC / other hardware

Treat these as current-runtime checks, not active historical tasks. If a subsystem is broken now, create a focused child ticket under `nd-gv62` with current evidence and acceptance criteria.

Known non-invasive RTC mitigation exists: a host-local time seed restore/save service and timer reduce 1970-era boot-time fallout before network time is available. True PMIC RTC persistence remains kernel/firmware/device-tree territory.

## Useful commands

```sh
# Work selection
tk show nd-gv62
tk ready
tk blocked

# Repo/runtime context
git status --short
git log --oneline -n 10
hostname
uptime
journalctl --list-boots --no-pager | tail -5
systemctl --failed

# Current boot logs
sudo journalctl -b -k --no-pager
sudo dmesg

# Audio diagnostics, only when relevant
nix run .#debug-oneplus-mic -- --help || true
nix run .#oneplus-mic-trial -- --help || true
nix run .#oneplus-loop-seed-reboot -- --help || true
```

## Documentation policy

Keep this file short and current. Put active task state in tk. Put reusable procedures in `docs/oneplus-agent-loop.md` and `docs/oneplus-debug-tools.md`. Keep old narratives in archive/git history unless a current ticket explicitly needs them.
