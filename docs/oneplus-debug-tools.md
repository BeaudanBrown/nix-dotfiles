# OnePlus Debug Tools

This file is the discovery index for reusable OnePlus diagnostics. Agents should check here before creating new scripts.

## Existing tools

### `nix run .#debug-oneplus-mic`

Detailed audio/microphone diagnostic runner. It collects ALSA, PipeWire, DAPM/debugfs, route, capture, and related evidence for OnePlus audio work.

Use only when the active ticket needs audio evidence. Prefer adding modes to this tool over pasting large one-off mic scripts into tickets.

### `nix run .#oneplus-mic-trial`

Traceable wrapper around `debug-oneplus-mic` that writes a short Markdown trial record under `docs/oneplus-audio-trials/`. It deliberately does **not** commit; agents must review and commit the record manually with the related code/docs/ticket changes.

Use for microphone experiments that future agents may compare.

### `scripts/record-oneplus-touch-events.sh`

Touch/gesture capture helper for touchscreen, lisgd/niri, and terminal-scroll investigations. Use or extend it before creating new touch debugging snippets.

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
5. record the first use in the active tk ticket.

Keep large raw outputs out of top-level docs. Put durable conclusions in tk notes and `docs/oneplus-bringup.md`; put bulky artifacts in purpose-specific generated records or temporary paths referenced from tickets.

## Current tool gaps worth considering

Create these only when a ticket needs them:

- a current-runtime health snapshot tool for failed units, boot IDs, network, display, audio, battery, and basic hardware inventory;
- a display/DRM warning collector for `msm_dpu`, vblank, SMMU, GPU firmware, and user-visible display state;
- a patchable-kernel experiment helper once `nd-qa6a` defines the supported flow.
