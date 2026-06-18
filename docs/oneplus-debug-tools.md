# OnePlus Debug Tools

This file is the discovery index for reusable OnePlus diagnostics. Agents should check here before creating new scripts.

## Existing tools

### `nix run .#debug-oneplus-mic`

Detailed audio/microphone diagnostic runner. It collects ALSA, PipeWire, DAPM/debugfs, route, capture, and related evidence for OnePlus audio work.

Use only when the active ticket needs audio evidence. Prefer adding modes to this tool over pasting large one-off mic scripts into tickets.

### `nix run .#oneplus-mic-trial`

Traceable wrapper around `debug-oneplus-mic` that writes a short Markdown trial record under `docs/oneplus-audio-trials/`. It deliberately does **not** commit; agents must review and commit the record manually with the related code/docs/ticket changes.

Use for microphone experiments that future agents may compare.

### `nix run .#oneplus-audio-readings`

Bounded non-kernel audio reading helper for the current OnePlus runtime. It plays a short speaker probe and records the PipeWire sink monitor, then records each currently visible ALSA/PipeWire capture source and reports `max`/`rms` readings in a TSV summary. By default it does not change mixer routing.

Examples:

```sh
nix run .#oneplus-audio-readings -- --seconds 2
nix run .#oneplus-audio-readings -- --seconds 2 --route-bottom-mic
```

Use `--route-bottom-mic` only for an explicit reversible experiment: it applies the known AMIC4/ADC4 route, loads a transient `oneplus_bottom_mic_trial` PipeWire Pulse source, records it, and unloads the module before exit. Review the generated `/tmp/oneplus-audio-readings-*` artifact and copy durable conclusions into tk/docs; the tool does not commit.

### `scripts/record-oneplus-touch-events.sh`

Touch/gesture capture helper for touchscreen, lisgd/compositor, and terminal-scroll investigations. Use or extend it before creating new touch debugging snippets.

### `nix run .#oneplus-screenshot`

Captures the current Wayland UI to a PNG under `/tmp/oneplus-agent-ui/` by default and prints a Pi `read` hint. Use it whenever an agent needs to see what the phone is displaying.

Examples:

```sh
nix run .#oneplus-screenshot -- --label current-ui
nix run .#oneplus-screenshot -- --out /tmp/oneplus-agent-ui/manual.png
```

The tool uses `grim`, performs one capture, and never commits artifacts. Do not commit screenshots by default; summarize non-sensitive observations in tk/docs.

### `nix run .#oneplus-touch`

Sends one bounded pointer action through `ydotool`. It supports dry-run checks, taps, and single-finger swipes with explicit absolute coordinates.

Examples:

```sh
nix run .#oneplus-touch -- --dry-run tap 540 1200
nix run .#oneplus-touch -- tap 540 1200
nix run .#oneplus-touch -- swipe 540 1800 540 600 --duration-ms 400
```

If it reports a missing `ydotool` socket, boot into a generation with the OnePlus-local `programs.ydotool` config and ensure the user session is in the `ydotool` group. Do not script unattended interaction loops.

### `nix run .#oneplus-hyprspace-state`

Prints a bounded Hyprland/Hyprspace runtime snapshot: plugin list, monitors, active workspace, clients, layout, and relevant overview options such as `previewDrag` and `debugHitboxes`.

### `nix run .#oneplus-hyprspace-setup-test`

Creates deterministic `hyprspace-test-*` Ghostty windows, moves them to known workspaces, focuses workspace 1, optionally opens overview, and prints a concise clients summary.

Example:

```sh
nix run .#oneplus-hyprspace-setup-test -- --windows 3 --open-overview
```

### `nix run .#oneplus-hyprspace-hitboxes`

Reads recent Hyprspace debug hitbox logs from the user journal and Hyprland runtime logs. Enable `plugin:overview:debugHitboxes = 1` and open overview once before using it.

### `nix run .#oneplus-hyprspace-drag-preview`

Performs exactly one deterministic preview drag gesture. Supports `--dry-run` and prints coordinates/backend before acting. Coordinates are Hyprspace/Hyprland logical coordinates matching `oneplus-hyprspace-hitboxes` output. Add `--screenshot-label <label>` to pause with the pointer held down, capture one screenshot, then release; this is useful for drag-ghost validation.

Examples:

```sh
nix run .#oneplus-hyprspace-drag-preview -- --from 150 1060 --to 270 1040 --duration-ms 600
nix run .#oneplus-hyprspace-drag-preview -- --from 150 1060 --to 270 1040 --duration-ms 800 --screenshot-label preview-rect-ghost
```

### `nix run .#oneplus-key`

Sends one bounded key or text action. Basic key names include `enter`, `escape`, `tab`, `backspace`, arrows, `back`, `home`, `volume-up`, `volume-down`, and `power`. Text input prefers `wtype` under Wayland and falls back to `ydotool type`.

Examples:

```sh
nix run .#oneplus-key -- --dry-run enter
nix run .#oneplus-key -- enter
nix run .#oneplus-key -- text "hello"
```

`back`, `home`, and `power` semantics depend on the compositor/input stack; verify with screenshots and record results before relying on them for a ticket.

### UI observe-control workflow

Use an observe → act → observe loop for display/touch/app-navigation tickets:

1. Capture current state:

   ```sh
   nix run .#oneplus-screenshot -- --label before
   ```

2. Read the printed PNG path with Pi's image `read` tool.
3. Perform one explicit action:

   ```sh
   nix run .#oneplus-touch -- tap 540 1200
   nix run .#oneplus-touch -- swipe 540 1800 540 600 --duration-ms 400
   nix run .#oneplus-key -- escape
   ```

4. Capture and read the after state:

   ```sh
   nix run .#oneplus-screenshot -- --label after
   ```

5. Record the observation, command, and result in the active tk ticket.

### `nix run .#oneplus-loop-seed-reboot`

Seeds a OnePlus `/aloop` reboot handoff by writing `.pi/boot-task.md` and optional `.pi/boot-next-loop.md`. It records the active ticket, current commit, post-boot checks, and an advisory `/aloop 1 nd-gv62` continuation. It deliberately does **not** commit, run `nr`, or reboot.

Example:

```sh
nix run .#oneplus-loop-seed-reboot -- nd-xxxx --checks "Confirm display returns, inspect failed units, and record PASS/FAIL in tk."
```

### `scripts/pi-boot-seed.sh`

Writes `.pi/boot-task.md` for a generic next boot-resume handoff.

Example:

```sh
scripts/pi-boot-seed.sh "Continue ticket nd-xxxx after reboot. Do not reboot again. Check ..."
```

### `scripts/pi-boot-resume.sh`

Started by the OnePlus graphical session to reopen pi/tmux after login and send `.pi/boot-system.md` plus `.pi/boot-task.md` and optional `.pi/boot-next-loop.md` into the newest Pi session.

### `nr`

Repo-provided NixOS iteration command. On OnePlus it builds a boot generation and sets it as next boot instead of doing a normal desktop switch. Commit coherent changes before `nr`; do not run `nix eval` immediately before it.

## Promotion rule for new tools

If an agent writes a diagnostic or helper that is likely useful again, make it discoverable:

1. put the script under `scripts/` with a narrow, descriptive name;
2. add a `.nix` wrapper with `pkgs.writeShellApplication` when dependencies matter;
3. expose it as a flake `package` and possibly an `app` when agents should run it with `nix run`;
4. add an entry here with purpose, command, and output location;
5. for UI interaction tools, include a dry-run mode and an observe-control example;
6. record the first use in the active tk ticket.

Keep large raw outputs out of top-level docs. Put durable conclusions in tk notes and `docs/oneplus-bringup.md`; put bulky artifacts in purpose-specific generated records or temporary paths referenced from tickets.

## Current tool gaps worth considering

Create these only when a ticket needs them:

- a current-runtime health snapshot tool for failed units, boot IDs, network, display, audio, battery, and basic hardware inventory;
- a display/DRM warning collector for `msm_dpu`, vblank, SMMU, GPU firmware, and user-visible display state;
- a combined `oneplus-ui-workflow` helper that captures before/after screenshots around one touch/key action;
- a `oneplus-input-discover` helper that reports screen size, input backends, ydotool socket state, and relevant devices;
- a non-kernel audio reading helper that plays a bounded speaker test, records bounded ALSA/PipeWire mic samples, and reports positive/zero levels without changing persistent routing by default.
