# Grill: dedicated Moonlight output

## Temporary fixed mode (active on Grill)

With `custom.sunshine.fixedStream = true`, Sunshine's user service creates one
1080p60 headless output named `STREAM` before starting in the Hyprland session.
No physical monitor or `WOL-FALLBACK` is required. The **Streaming Desktop**
entry has no prep or cleanup hooks, so quitting does not resize the output.
Launch Steam manually if needed. Pairings and Hyprlock are unchanged.

To test over SSH without rebooting, save and close anything on `STREAM`, stop
both old user services, then activate with `sudo nixos-rebuild test --flake .#grill`.
If the old `STREAM` is still at the wrong mode, stop Sunshine and remove that
output with `hyprctl -i 0 output remove STREAM` before starting Sunshine again.
Do not remove an output with unsaved work. Verify `STREAM` stays at 1080p60 after
quitting a Moonlight stream and launching it again.

Set `custom.sunshine.fixedStream = false` to restore the dynamic controller and
Steam Big Picture entry. The rest of this document describes that dynamic mode.

## Scope and agreed behavior

One existing Hyprland session and one Sunshine instance capture a persistent
headless output called `STREAM`, with one named ordinary workspace `streaming`.
This is not a security-isolated desktop and input/focus are shared with the local
seat. Both physical displays keep their existing 2560x1440/144 Hz modes.

- Fresh application start: validate client dimensions/FPS, save restoration state,
  resize the output, focus its workspace and centre the cursor.
- Temporary disconnect: no desktop, game, resolution, or ownership changes.
- Resume: restore focus/cursor only; keep the session's original display mode.
- Explicit Quit Application: request graceful closure of game windows attributed
  to this session, leave Big Picture if this session opened it, restore surviving
  windows/focus/cursor, and return to 640x360/10 Hz.
- A game that refuses closure, or a game of uncertain ownership, blocks cleanup.
  Never force-kill or shrink a display underneath it. Save/close it manually and
  retry `stream-session stop`.
- Mode changes wait up to two seconds after Hyprland acknowledges the rule.
  If the mode never applies, the controller logs the requested and last observed
  mode and retains the recovery snapshot.
- Controller restart: recover the snapshot in the same Hyprland instance. Never
  reset an existing output simply because a service restarted. Lost output or
  corrupt state fails closed instead of inventing a recovery policy.

The first supported client-mode range is 320–7680 pixels wide, 200–4320 high and
10–144 FPS. New modes apply only to new application sessions. FSR, HDR,
physical-display switching, concurrent independent seats and concurrent clients
with different output modes are outside this implementation.

## Implementation and ownership

`modules/services/sunshine/stream-session/` is a repository-owned Cabal package.
`grill.nix` builds it with pinned `haskellPackages` and wraps the executable with
its Hyprland, Steam, systemd and launcher dependencies. No Python production code
or test harness is used.

`stream-session.service` is a primary-user-only, `Type=notify` service attached
to `graphical-session.target`. It creates/verifies the output before notifying
systemd; `sunshine.service` requires it and starts afterward. A Unix socket with
mode 0600 accepts preparation, launch, cleanup, status and navigation commands.
A daemon lock prevents two controllers from owning the same compositor instance.
Commands and events are serialized. Same-user IPC is not a sandbox boundary.

The process listens to Hyprland's event socket for new game/Big Picture windows,
workspace enforcement and navigation history. Sunshine's explicit prep/undo
hooks own application lifetime. A narrow journal adapter observes the installed
Sunshine version's `Info: CLIENT CONNECTED` message to refocus on resume; it is
not a stable upstream API. It never infers cleanup from logs. Journal/socket
failure causes a supervised restart with the saved session intact. Recheck this
adapter when updating Sunshine.

Runtime state lives under
`$XDG_RUNTIME_DIR/stream-session/$HYPRLAND_INSTANCE_SIGNATURE/`, not the Nix store.
Snapshots are atomically replaced before external effects. `Preparing` or
`Closing` after failure requires explicit cleanup/retry, not automatic destructive
recovery. Window ownership is conservative: only newly observed `steam_app_*`
windows absent from the pre-session window/process set are claimed. Address,
PID and class must still match before close. Windows appearing while observation
was unavailable are not adopted for closure during recovery. Generic non-Steam
games/launchers are not automatically killed.

Steam URI invocations run through independent transient systemd user services,
not inside Sunshine's or the controller's cgroup. Restarting either controller
must not kill its launched Steam process. Explicit stop leaves the Steam client
itself running; it closes session-owned games and leaves Big Picture. Existing
Big Picture is restored rather than closed.

## Hyprland integration

Grill-only changes in the existing keybinding/window/workspace modules:

- `Super+H`, `Super+Shift+H`, `Super+Alt+H` cycle/focus/move only physical monitors.
- `Super+Tab` uses ordinary-workspace history; `Super+Shift+Tab` cycles ordinary
  workspaces on the focused physical monitor.
- `Alt+Tab` excludes windows on `streaming`.
- Steam launch/pull shortcuts focus the active streaming session rather than
  pulling its Steam window back to the physical desktop.
- New non-modal windows on `streaming` default to fullscreen. Steam/game windows
  routed there after mapping are also explicitly fullscreened.
- An event guard moves other workspaces off `STREAM` and restores its designated
  workspace. This is eventual enforcement, not a prohibition on raw `hyprctl`
  commands or deliberate manual moves. The output is positioned at 10000x10000
  to prevent ordinary pointer travel from reaching it.

No physical monitor modes are rewritten. Named application shortcuts and manual
commands are still available; this is navigation policy, not access isolation.

## Declarative Sunshine

`services.sunshine.settings` and `.applications` generate read-only Nix-store
configuration. The UI cannot persist edits to these files. Existing credentials,
certificates and client pairings stay in Sunshine's user-owned state; they are not
embedded in Nix. Preserve `~/.config/sunshine/` when deploying.

Settings preserve the tested `generic` gamepad, `wlr` capture, `vaapi` encoding,
Right-Alt-to-Super mapping and `STREAM` target. UPnP is disabled, HEVC is SDR-only,
AV1 advertisement is disabled for the RX 6900 XT, and Moonlight controls bitrate.
The KMS-only CAP_SYS_ADMIN wrapper is no longer used.

Applications are **Streaming Desktop** and **Steam Big Picture**. The stale X11
Low Res Desktop entry and temporary lifecycle probe are not deployed.

## Tailnet management UI

NAS registers `sunshine.bepis.lol` with `hostedServices`, `tailnet = true` and
WebSocket forwarding. Its location overrides only the generated `proxyPass` to
`https://<grill-tailnet-ip>:47990`. `proxy_ssl_verify off` is intentional: the
backend uses Sunshine's certificate inside authenticated Tailscale transport;
no private CA or backend certificate lifecycle is introduced. Browser-facing
HTTPS still uses the hosted-services ACME certificate.

Basic Auth and Sunshine's CSRF protection remain enabled. No credentials are
injected and no extra trusted CSRF origins are configured. The UI remains an
administrative interface even though its configuration file is read-only.

Grill permits direct management-port traffic only from loopback or NAS's exact
IPv4 tailnet address arriving on `tailscale0`. IPv6 remote management is denied.
The iptables backend guard runs in raw PREROUTING before trusted-interface and
Tailscale ACCEPT rules. With the nftables backend, a separate input base chain
rejects other sources. Streaming ports remain available for LAN Moonlight.
`origin_web_ui_allowed = wan` permits the NAS proxy's source classification;
the firewall, not that broad Sunshine category, is the network access boundary.

## Verification and activation

No build/switch is implicit in this module. Required pre-activation checks:

- Cabal `model-tests`: validation, ownership and snapshot roundtrips.
- Cabal `integration-tests`: the actual controller executable, independent JSON
  client, fake OS executables, isolated Unix sockets/runtime directory and mock
  journal. Test fixtures are Haskell and never call real Hyprland/Steam/systemd.
- `nix eval .#nixosConfigurations.grill.config.system.build.toplevel.drvPath`
- `nix eval .#nixosConfigurations.nas.config.system.build.toplevel.drvPath`
- Verify generated Hyprland config using `Hyprland --verify-config -c FILE`.

Cabal declares the controller executable as the integration suite's build tool;
the Nix package enables checks. For a local compiled integration binary, set
`STREAM_SESSION_TEST_EXE` to the test controller binary. Do not point fixture
commands at a live compositor.

After separately approved builds, activate Grill and NAS using the repository's
normal rebuild/deploy workflow. Save and close the old trial game/Steam first:
the old Sunshine service may still own Steam in its cgroup and a service restart
could terminate it. Remove/stop any old temporary probe service before testing.
The new executable does not depend on the trial's `/run/user/.../observe.py` or
its temporary app file. A graphical-session restart is the cleanest first
activation; test controller readiness and environment import on that first login.

Live acceptance must verify:

1. Physical monitors remain 144 Hz; `STREAM` starts small and idle.
2. Both Moonlight entries start at client-requested size, with focus and mouse.
3. Steam/game placement, fullscreen, `generic` controller and audio work.
4. Disconnect/resume preserves game and mode, restoring focus on resume.
5. Explicit quit closes a cooperative game, restores desktop and shrinks output.
6. Unsaved/refusing and unowned games leave cleanup blocked without force-kill.
7. Controller restart during a game preserves it and its output.
8. Normal navigation does not reach the hidden monitor.
9. Tailnet UI serves valid browser TLS, requires Basic Auth, and pairing/state-
   changing operations work through the proxy without CSRF bypasses.
10. LAN/non-NAS tailnet direct port 47990 and public UI ingress are denied;
    localhost and the NAS proxy still work. Check IPv4 and IPv6.
11. Compare idle CPU/GPU power/VRAM before and after activation.

Useful commands after activation:

```sh
stream-session status
stream-session stop  # graceful retry after saving/closing a blocked game
systemctl --user status stream-session sunshine
journalctl --user -u stream-session -u sunshine
```

### Observed prototype evidence (2026-11-18)

The existing system successfully streamed the temporary headless monitor at
4K60. Logging-only hooks observed one prep at initial launch, no undo on
Moonlight disconnect, no prep or duplicate launch on resume, and one undo on
explicit Quit Application. Client variables in that lifecycle test requested
1920x1080/60 even though the temporary output remained 4K. This proves the hook
boundary, not acceptance of the new packaged controller or firewall/proxy.
