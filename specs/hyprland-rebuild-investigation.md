# Hyprland session teardown during rebuild: investigation

## Scope

Read-only investigation on t480, 2026-11-17. No rebuild, service restart, logout, or configuration fix was performed. A prior evaluation of `nixosConfigurations.t480.config.system.build.toplevel.drvPath` passed. No live activation reproduction was attempted because it could destroy the user's graphical session.

## Local evidence

Read using `journalctl --user -b`, `systemctl --user cat`, and `/proc/<pid>/cgroup`:

- At 16:49:56, `wayland-session-bindpid@2985.service` started and immediately triggered its `OnSuccess` dependencies.
- The installed UWSM 0.26.4 bindpid template has both `OnSuccess=wayland-session-shutdown.target` and `OnFailure=wayland-session-shutdown.target`. It waits for the PID encoded in its instance name.
- Systemd then stopped graphical-session applications, the session target, and `wayland-wm@start\\x2dhyprland.service`. Greetd subsequently opened the greeter session. There is no Hyprland coredump for this incident in the available list.
- PID 2985 was absent when checked; the current session's monitor instead watches PID 173069. Old bindpid instances also appear in teardown logs at 12:49 and 16:47.
- At 16:47:16 the user manager records reexecution requested by `switch-to-configuration`, immediately before the teardown sequence.

This establishes a systemd/UWSM session shutdown, not a demonstrated Hyprland crash. It does **not** yet establish why an obsolete bindpid instance was started. Restart/replay during activation is a leading hypothesis, not a proven root cause.

The installed switch-to-configuration Rust source at `/nix/store/l8nvd2l5ahmc1x2k8af3nqygi0d4fxlz-switch-to-configuration-ng/src/main.rs` seeds user-unit jobs from runtime start/restart/reload lists to resume interrupted activations, then reexecutes/reloads the user manager and submits jobs. This is one possible investigation seam; the current `/run/user/1000/nixos` directory contained no residual job lists. There is no retained list proving that mechanism caused this incident.

## Repository implementation review

- `modules/desktop/hyprland/work.nix` enables `programs.hyprland.withUWSM` and disables Home Manager's Hyprland systemd integration. This avoids competing graphical-session ownership.
- `modules/desktop/hyprland/autologin-hyprlock.nix` starts UWSM through greetd using `uwsm start -e -D Hyprland .../start-hyprland`. The observed greetd unit has `X-RestartIfChanged=false`, and its journal does not show a greetd service restart at the incident. No evidence currently implicates the login command.
- `modules/desktop/hyprland/scripts/hyprland_show_app.sh` launches applications directly through `hyprctl dispatch exec` or `eval`, without `uwsm app`. Ghostty launch definitions are in `modules/desktop/hyprland/keybinds/work.nix`.
- Both inspected Ghostty processes belonged to the compositor's `wayland-wm@start\\x2dhyprland.service` cgroup, confirming application/compositor lifecycle coupling. Launching applications through UWSM is a sensible independent improvement, but is not a demonstrated fix for stale bindpid activation.
- The current compositor unit has `NotifyAccess=exec`. The older `NotifyAccess=all` PID-hijack mechanism discussed in upstream issue 67 must not be assumed to apply to this installed configuration.

## Online reports and primary sources

1. [omarchy-nix issue 6](https://github.com/zicochaos/omarchy-nix/issues/6): closely matching NixOS 26.05 report. Live rebuild stops UWSM units including `wayland-session-bindpid@...`, kills the graphical session and updater terminal, and interrupts post-update work. The project changed its update default to boot-only activation. This corroborates the failure class, not the exact stale-PID cause here.
2. [UWSM issue 67](https://github.com/Vladimir-csp/uwsm/issues/67): Hyprland receives termination rather than crashing when Podman exits. Comments describe applications sharing the compositor cgroup and older notification-based MainPID replacement. Launching the terminal with `uwsm app --` resolved the reported case. Different trigger and potentially different unit semantics from this host.
3. [UWSM issue 129](https://github.com/Vladimir-csp/uwsm/issues/129): package upgrades appeared to crash a Sway session, but the reporter ultimately concluded it was unrelated to UWSM. Not evidence of a matching bug.
4. [nixpkgs PR 449958](https://github.com/NixOS/nixpkgs/pull/449958): documents a historical bindpid `waitpid: not found` issue, linked to [UWSM PR 175](https://github.com/Vladimir-csp/uwsm/pull/175). The current local template invokes an absolute waitpid path, so this is not the observed failure.
5. [UWSM upstream documentation](https://github.com/Vladimir-csp/uwsm): session lifecycle and application launch integration reference.

## Follow-up: configuration versus upstream versus reboot

Further read-only evidence narrows the classification:

- The first incident at 12:49:17 explicitly logs `Stopping Bind graphical session to PID 2985`, immediately followed by its `OnSuccess` shutdown dependencies. This was the original boot session's monitor, not initially an obsolete monitor.
- Comparing `/run/booted-system/etc/systemd/user/wayland-session-bindpid@.service` and `/run/current-system/etc/systemd/user/wayland-session-bindpid@.service` shows an `ExecStart` change: util-linux waitpid moved from 2.42.2 to 2.42.4, and the UWSM store path changed even though its version remained 0.26.4. Neither template has NixOS `X-RestartIfChanged=false`/`X-StopIfChanged=false` protection. `Restart=no` is systemd's automatic process-restart policy, not protection from NixOS activation jobs.
- The current switch-to-configuration executable's derivation confirms its source is the Rust source inspected above. That source handles changed services by default and records jobs for interrupted-run recovery. Thus a routine dependency update is sufficient to make this upstream session-monitor unit eligible for activation stop/start behavior.
- The booted generation is `26.05.20260730.21ea275`; the current generation is `26.05.20261102.7dcdd87`. This was a substantial live generation transition, not only an application configuration edit.
- The runtime recovery-list directory is now empty, and only the current PID 173069 monitor is loaded. No stale monitor/recovery list remains visible in these checks.

**Assessment:** strong evidence for an upstream NixOS activation/UWSM lifecycle interaction triggered by dependency changes, rather than a malformed local Hyprland configuration. The later obsolete-monitor replay is consistent with an interrupted activation, but the deleted historical job lists prevent proving that part. Reboot clears user-manager/runtime state and starts a coherent generation, so it should remove this episode's transient state; it does not prevent recurrence on future updates that change the same unit. Even without reboot, the currently visible stale state has already cleared. No claim that a subsequent live activation is safe has been tested.

## Verified upstream fix

[Nixpkgs PR #532275](https://github.com/NixOS/nixpkgs/pull/532275), merged 2026-06-16, explicitly says: “Fix the desktop session being killed when uwsm is updated.” Commit [184d1b4](https://github.com/NixOS/nixpkgs/commit/184d1b4c0f6e5e05e079a8a6cca67879a317ea2f) adds `restartIfChanged = false` and `enableDefaultPath = false` for `wayland-wm@` and `wayland-session-bindpid@` in the NixOS UWSM module. The latter avoids a generated default PATH overriding UWSM's session environment. The PR discussion requests a 26.05 backport.

Verified directly against GitHub source: current nixpkgs master contains the fix; this repository's actual root nixpkgs input does not. The root input maps to lock node `nixpkgs_4`, revision `7dcdd87373d72e7a2173e4db02e20d3d7f495cfd`, not the unrelated lock node named `nixpkgs`. The installed unit likewise lacks the protection. Therefore a local backport of the merged module change or adoption of an appropriate fixed nixpkgs revision is warranted; reboot alone cannot add it.

A focused local option evaluation was attempted, but concurrent work left `modules/apps/moonlight_qt/t480.nix` syntactically incomplete at that moment (unexpected EOF). This check did not pass; no unrelated file was modified. The upstream status and pinned-source comparison above were verified independently through GitHub's API/raw source.

## Recommended next steps

1. Investigate activation's treatment of PID-bound UWSM units, using an isolated user-manager/fixture test rather than deliberately restarting the live desktop. Preserve actual unit-submission lists if a controlled live reproduction is later approved.
2. Independently adapt the custom application launcher to use `uwsm app`, preserving arguments and workspace behavior; test both launcher branches.
3. For large desktop-stack updates, boot-only rebuild followed by a planned reboot avoids live activation teardown. This is a workaround, not proof that ordinary live rebuilds must always end a session.
4. Do not mask bindpid or remove its shutdown hooks blindly: those hooks implement real logout cleanup. A restart-policy override also requires verification against the actual activation path before claiming a fix.
