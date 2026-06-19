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
- `nd-ihy2` — completed initial non-kernel speaker/microphone reading stabilization
- `nd-iwoo` — validate mic measurement path
- `nd-h6lz` — ALSA/PipeWire capture matrix
- `nd-zthm` — mic mixer controls
- `nd-vnpn` — UCM/vendor route comparison
- `nd-296h` — audio service ordering
- `nd-ts1j` — firmware/DSP runtime logs
- `nd-y7b7` — microphone fallback input options
- `nd-d6hc` — classify missing Bluetooth controller after audio work
- `nd-y7lt` — stop sentinel; depends on all actionable work and closes the loop when no actionable work remains

Removed from the active queue: `nd-qa6a`, the patchable/test-kernel experiment flow, is closed/cancelled and should not be pursued unless future user direction explicitly reintroduces kernel builds.

If a new issue is discovered, add it as a focused child ticket and wire it into this dependency chain instead of relying on ticket creation time or prose priority.

The previous backlog and its child tickets are superseded and should not guide new work.

## Runtime areas

### Boot / resume

Boot-resume is manual-only: run `scripts/pi-boot-resume.sh` when a reboot validation needs a prompt. The helper attaches to tmux and sends `.pi/boot-system.md` plus `.pi/boot-task.md` and optional `.pi/boot-next-loop.md` into the newest Pi session. These `.pi` task files are untracked and should be rewritten for each reboot validation.

### Networking

NetworkManager/iwd/Tailscale are configured for the host. Agents should validate current connectivity from runtime state rather than relying on old notes.

### Bluetooth

The host enables NixOS Bluetooth support directly because the phone does not import the work-root desktop Bluetooth module. Validate adapter and service state after changes with current runtime commands.

### Display / UI / touch

The current UI stack is Hyprland/Ghostty with OnePlus-specific startup and gesture helpers. The previous Niri config remains in `hosts/oneplus/oneplus-fajita/ui/niri.nix` as the quick rollback reference; the active Hyprland config is `hosts/oneplus/oneplus-fajita/ui/hyprland.nix`. A focused terminal-scroll bridge exists there and should be validated/tuned from current touch behavior if needed.

Agents can now observe and interact with the live UI through flake tools documented in `docs/oneplus-debug-tools.md`:

- `nix run .#oneplus-screenshot -- --label before` captures a PNG and prints a Pi image `read` hint.
- `nix run .#oneplus-touch -- tap 540 1200` or `swipe ...` sends one explicit pointer action through ydotool.
- `nix run .#oneplus-key -- enter` or `text ...` sends one explicit key/text action.

Use observe → act → observe for UI/display/touch work and record conclusions in tk. Do not commit screenshots by default.

Display/GPU warnings should be investigated under current tickets only when they recur or correlate with visible instability. Use current `dmesg`/journal evidence plus screenshots when useful; do not chase historical warning clusters by default.

Current classification from `nd-6g7r` (2026-06-16): no actionable display/GPU instability was found on the live host. Current and previous boot kernel logs had no DRM/MSM/DPU/Adreno/SMMU/vblank/display matches; the current user journal had one early Niri `vblank_throttle` warning for `DSI-1` about a 0 ns vblank. The panel is active as `DSI-1` at 1080x2340@60 Hz, Niri/Ghostty remain running, and screenshots before/after a safe Escape key action showed a readable, non-glitched UI. Treat this single userspace vblank warning as benign unless it recurs, clusters, or coincides with visible blanking, flicker, compositor crashes, or input/display lag.

### Audio / microphone

Speaker playback is the stable supported audio path. The host keeps a conservative userspace shape for audio:

- speaker playback through the OnePlus UCM/ACP path;
- `oneplus-audio-route.service` initializes the speaker route before WirePlumber;
- `oneplus-mic-source.service` is manual-only;
- bottom-mic work should use `docs/oneplus-debug-tools.md` and active tickets.

The current bottom-mic work is non-kernel focused under the `nd-gv62` microphone chain: seek repeatable positive/zero readings through ALSA/PipeWire/WirePlumber/UCM/mixer/service experiments while preserving speaker playback. Do not compile kernels, add kernel patches, or create a test-kernel path for this loop. Avoid broad UCM/PipeWire microphone rewrites unless current evidence and the active ticket justify a small reversible experiment. The repeatable readings procedure and latest route evidence are in `docs/oneplus-audio-readings.md`: `nd-iwoo` confirmed the exact-zero mic samples are reproducible across helper, direct ALSA, and direct PipeWire capture/analysis paths; `nd-h6lz` mapped the visible ALSA/PipeWire capture matrix; `nd-zthm` found high-gain ADC4 TX7/TX0 routes can produce non-zero samples; `nd-vnpn` compared current speaker-only UCM with Oxygen vendor routes; `nd-296h` ruled out current-runtime service/PipeWire/WirePlumber ordering as a microphone fix; `nd-ts1j` found no userspace-remediable missing-firmware, remoteproc crash, or service-log failure; and `nd-y7b7` documented fallback input choices. The current unresolved userspace mismatch is that UCM has no capture device, while vendor bottom-mic routes map bottom `builtin_mic_1` to `TX0/DEC0/ADC4` or dual `TX7/TX8` ADC4+ADC3 routes that produce only low/noise-like non-zero samples in bounded trials; capture attempts also correlate with lower-level SLIM/WCD TX-port timeout/overflow logs. The recommended practical microphone fallback is a class-compliant USB-C audio adapter/headset or USB microphone, because it should bypass the internal WCD/TX path; Bluetooth remains deferred until `nd-d6hc`, and network/remote audio is an app-level workaround when another device can supply the mic.

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
