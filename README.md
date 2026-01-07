# NixOS Dotfiles

Flake-based, multi-host NixOS/Home Manager configuration with a clean, scalable module system and strict formatting/linting. Hosts are auto-exposed as `.#nixosConfigurations.<host>` by enumerating `hosts/`.

## Structure

- `hosts/<host>/` — Per-host entrypoint (`default.nix`) and `hardware.nix`; each host declares its `roots` set.
- `modules/**` — Feature modules by category: `apps`, `cli`, `desktop`, `services`, `system`, `hardware`, `security`, `tools`, `gaming`.
- `lib/` — `lib.custom` utilities for module discovery (`importAll`, `importHost`) and option helpers.
- `nixos-installer/` — ISO build configuration.
- `secrets/` — SOPS-managed secrets (encrypted; not edited here).

## Composition Model

- Roots pattern: files named `<root>.nix` (e.g., `minimal.nix`, `work.nix`) are included when a host enables that root.
- Host overrides: `{hostname}.nix` files load alongside any feature for targeted tweaks.
- Home Manager is injected automatically via the import pipeline; modules may use `hm.*` without extra wiring.
- Multi-channel aware: a stable/unstable split is available; modules can opt into `nixpkgsStable` while the system uses a single `pkgs` baseline.

## Why This Design

- Predictable composition via roots + filename-based discovery.
- Low boilerplate through centralized import and option helpers (`importAll`, `enabled`/`disabled`, `mkOpt`).
- First-class integrations: Stylix (theming), NixVim, Disko, SOPS for a cohesive desktop/dev/ops setup.

## Workflow

- Format and checks: `nix fmt`, `nix flake check` (pre-commit: `nixfmt-rfc-style`, `deadnix`, `shellcheck`, `shfmt`, no submodules).
- Common tasks with `just`:
  - `just update` — Update flake inputs
  - `just iso` — Build installer ISO; `just test-iso` to run in QEMU
  - `just build <HOST>` — Build system closure
  - `just deploy-test <HOST>` — Dry-activate on remote
  - `just deploy <HOST>` — Switch remote host
  - `just sync USER HOST PATH` — Rsync config to remote path

## Quick Start

1) Add a host: create `hosts/<name>/default.nix` + `hardware.nix` and set `roots = [ "minimal" "common" ... ]`.
2) Add features: place modules under `modules/<category>/<feature>/<root>.nix` and enable the matching root in the host.
3) Build/switch: `nixos-rebuild switch --flake .#<name>` or `nix build .#nixosConfigurations.<name>.config.system.build.toplevel`.
4) Secrets: manage via SOPS; reference in modules with `config.sops.secrets.<name>.path`.
5) ISO: `just iso` to build, `just test-iso` to boot in QEMU.

## Security

- Secrets are encrypted with SOPS; never commit plaintext secrets. Use the referenced secret paths inside modules.

---

Designed for clarity, portability, and fast iteration across laptops, desktops, and servers.
