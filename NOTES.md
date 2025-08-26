# Remote builds and push-deploy for Raspberry Pi

This note captures the plan, what’s done, what’s next, and key pointers for continuing work. Target: NAS builds for Raspberry Pis (aarch64), then push-deploy to the Pis.

## Summary of approach

- Build on NAS using QEMU binfmt emulation for aarch64.
- Use push-deploy from NAS to Pi over SSH (nixos-rebuild --target-host ...).
- Keep a “pull” model available later (Pi orchestrates using NAS as a remote builder via nix.buildMachines) if needed.
- Root semantics clarified:
  - network: tailnet-enabled machines (e.g., Tailscale) + related desktop bits (Kitty) that should exist on tailnet computers.
  - main: primary machines (desktop, laptop, server) that get additional features like Opencode and Syncthing.

## Completed

- NAS cross-building for aarch64
  - Added module: `modules/nix/server.nix` (enables `boot.binfmt.emulatedSystems = ["aarch64-linux"]` and sets `nix.settings.max-jobs = 8`).
  - NAS can build `.#nixosConfigurations.pi4.config.system.build.toplevel`.

- Push-deploy helpers (NAS → Pi)
  - Added Just recipes in root `justfile`:
    - `just build HOST` (e.g., `build-pi4`)
    - `just deploy-test HOST` (dry-activate)
    - `just deploy HOST` (switch)
    - Convenience: `build-pi4`, `deploy-test-pi4`, `deploy-pi4`

- Root restructuring (scoped roll-out)
  - Re-purpose `network` to mean “tailnet machines + Kitty”.
  - Introduce `main` for desktop/laptop/server extras.
  - Moved Opencode and Syncthing under new `main` root modules:
    - `modules/cli/opencode/main.nix`
    - `modules/services/syncthing/main.nix`
  - Updated host roots:
    - Grill (desktop): [minimal, common, network, main, work, gaming]
    - Laptop: [minimal, common, network, main, work]
    - NAS (server): [minimal, common, network, main, server]
    - Pi4: [minimal, common, network]

## In progress / TODO

- Pull model (optional, later):
  - Pi uses NAS as remote builder: set `nix.distributedBuilds = true` and `nix.buildMachines` on Pi.
  - Add `nix.sshServe.*` on NAS (ssh-ng, write, trusted, keys) and sops-managed SSH key for Pi’s builder user.

- Keys/secrets
  - Ensure Pi4 has sops-provisioned SSH private key for push (already have user SSH setup under `modules/services/ssh/minimal.nix`; confirm paths/ownership).
  - Tailscale auth key secret: `"headscale/pre_auth"` already referenced by `modules/services/tailscale/network.nix`.

- HostSpec enhancements (optional)
  - Consider `hostSpec.builderHost`, `builderPort`, `builderUser`, `builderSystems` to avoid hardcoding builder details across hosts.

- Tests
  - Smoke test: `nix build .#nixosConfigurations.pi4.config.system.build.toplevel` on NAS (succeeds as of last run).
  - Deploy test: `just deploy-pi4`.

## How to operate

- Build on NAS (aarch64 target):
  - `just build-pi4`

- Push deploy to Pi4:
  - `just deploy-pi4`
  - Uses SSH Host alias `pi4` (defined in `modules/services/ssh/minimal.nix` via HM matchBlocks):
    - Hostname: 192.168.1.122, User: beau, Port: 8023
  - `--use-remote-sudo` is set; sudo permissions already allow `nixos-rebuild`.

## Important module pointers

- Cross-building on NAS: `modules/nix/server.nix`
- Tailscale (tailnet): `modules/services/tailscale/network.nix`
- Kitty: `modules/apps/kitty/network.nix`
- Opencode (main): `modules/cli/opencode/main.nix`
- Syncthing (main): `modules/services/syncthing/main.nix`
- SSH config and keys (baseline): `modules/services/ssh/minimal.nix`

## Host roots (current)

- Grill (desktop): `hosts/grill/default.nix` → [minimal, common, network, main, work, gaming]
- Laptop: `hosts/laptop/default.nix` → [minimal, common, network, main, work]
- NAS: `hosts/nas/default.nix` → [minimal, common, network, main, server]
- Pi4: `hosts/pi4/default.nix` → [minimal, common, network]
- ISO: `hosts/iso/default.nix` → [minimal]

## Notes and conventions

- Keep secrets in sops: do not commit plaintext keys. References used:
  - Tailscale pre-auth: `sops.secrets."headscale/pre_auth"`
  - SSH keys for users and services go under `secrets.yaml` and are mapped in modules.
- Use the roots suffix to target environments:
  - `network` for tailnet machines + user-facing terminal defaults
  - `main` for the three primary machines (desktop, laptop, server) to receive extended user tooling
- Formatting: `nixfmt-rfc-style` enforced by pre-commit; `deadnix` removes unused.

## Next steps snapshot

- Optional: finish the “pull” builder path (remote builders) by adding:
  - NAS: `nix.sshServe.enable = true; protocol = "ssh-ng"; write = true; trusted = true; keys = [ <Pi public key> ];`
  - Pi: `nix.distributedBuilds = true; nix.buildMachines = [ { hostName = "nas.lan"; protocol = "ssh-ng"; sshUser = "nix-ssh"; sshKey = "/root/.ssh/id_ed25519"; system = "x86_64-linux"; systems = [ "aarch64-linux" ]; maxJobs = 8; supportedFeatures = [ "nixos-test" "benchmark" "big-parallel" ]; } ];`

- If more Pis are added (e.g., armv7l): also include `"armv7l-linux"` in NAS `boot.binfmt.emulatedSystems` and set `systems = ["armv7l-linux"]` on build machine entries.

- Consider a small README section describing root semantics so future changes stay consistent.
