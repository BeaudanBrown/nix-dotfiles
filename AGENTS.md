# Agent Guidelines for NixOS Dotfiles

## Project Overview

This is a **flake-based NixOS fleet management** repository with a modular architecture. It manages multiple hosts (desktops, laptops, servers, Raspberry Pi) through a unified configuration system.

**Architecture**: Hosts → Roots → Modules

- **Hosts**: Individual machines with specific hardware and feature requirements
- **Roots**: Feature categories that determine which modules are imported
- **Modules**: Reusable configuration units organized by function

## Quick Reference

### Directory Structure

| Directory            | Purpose                                              |
|----------------------|------------------------------------------------------|
| `/hosts/`            | Host-specific entry points (grill, nas, laptop, etc.)|
| `/modules/`          | Reusable modules organized by category               |
| `/modules/host-spec/`| Central host registry (`all-hosts.nix`)              |
| `/lib/`              | Custom library functions                             |
| Private `sops-secrets` repo | Encrypted SOPS files and `.sops.yaml`        |
| `/specs/`            | Detailed technical specifications                    |
| `/hosts/installer/`  | Encrypted fleet-generic USB installer configuration  |

### Specification Files

Before starting a task, read the relevant specification:

| Spec File                    | When to Read                                   |
|------------------------------|------------------------------------------------|
| [specs/hosts.md](specs/hosts.md)       | Adding/modifying hosts, understanding hostSpec |
| [specs/roots.md](specs/roots.md)       | Understanding conditional imports, adding roots|
| [specs/modules.md](specs/modules.md)   | Creating/editing modules, using `hm.` pattern  |
| [specs/secrets.md](specs/secrets.md)   | Working with secrets (reference only)          |
| [specs/tooling.md](specs/tooling.md)   | Build commands, flake structure, pre-commit    |
| [specs/installer.md](specs/installer.md)| ISO building and installation                 |

## Core Workflow

Use `fd` instead of `find` for repository and Nix store discovery when available. Prefer commands like `fd -a PATTERN PATH` for locating package sources, generated store files, layouts, and configs.

When implementing a change, follow this decision tree:

### Step 1: Identify Target Host(s)

- Single host? → May need `<hostname>.nix` override
- Multiple similar hosts? → Use appropriate root
- All hosts? → Use `minimal.nix` or `common.nix`

### Step 2: Check Host's Roots

Look in `modules/host-spec/all-hosts.nix` to see which roots are enabled:

```nix
grill = {
  roots = [ "minimal" "common" "network" "client" "main" "work" "gaming" ];
};
```

### Step 3: Map to Module Category

| Feature Type           | Directory               |
|------------------------|-------------------------|
| GUI application        | `modules/apps/`         |
| CLI tool/shell         | `modules/cli/`          |
| Desktop/WM             | `modules/desktop/`      |
| Gaming                 | `modules/gaming/`       |
| Hardware               | `modules/hardware/`     |
| System service         | `modules/services/`     |
| Web/hosted service     | `modules/hosted-services/` |
| Core system            | `modules/system/`       |
| Development tool       | `modules/tools/`        |
| Security               | `modules/security/`     |

### Step 4: Choose Correct Filename

Name your file after the root it should be imported for:

| Filename       | Imported When                    |
|----------------|----------------------------------|
| `minimal.nix`  | All hosts (required features)    |
| `common.nix`   | Interactive systems              |
| `network.nix`  | Network-connected hosts          |
| `client.nix`   | Desktop/GUI hosts                |
| `server.nix`   | Headless servers                 |
| `work.nix`     | Development machines             |
| `gaming.nix`   | Gaming-capable machines          |
| `<hostname>.nix` | Specific host only             |

## OnePlus Agent Loop Queue

For OnePlus (`hosts/oneplus`) stabilization work, start from `docs/oneplus-loop-bootstrap.md` and the active tk epic `nd-gv62`. The queue is maintained with tk dependencies so fresh `/aloop 1 nd-gv62` workers pick up where the last worker stopped.

Current intentional order:

1. `nd-qbd8` current runtime scan
2. `nd-6g7r` display stability classification, depends on `nd-qbd8`
3. `nd-ihy2` completed initial non-kernel speaker/microphone reading stabilization
4. `nd-iwoo` validate mic measurement path
5. `nd-h6lz` ALSA/PipeWire capture matrix, depends on `nd-iwoo`
6. `nd-zthm` mic mixer controls, depends on `nd-h6lz`
7. `nd-vnpn` UCM/vendor route comparison, depends on `nd-zthm`
8. `nd-296h` audio service ordering, depends on `nd-vnpn`
9. `nd-ts1j` firmware/DSP runtime logs, depends on `nd-296h`
10. `nd-y7b7` microphone fallback input options, depends on `nd-ts1j`
11. `nd-d6hc` Bluetooth controller classification, depends on `nd-y7b7`
12. `nd-y7lt` stop sentinel, depends on all actionable work

When adding OnePlus follow-up work, create a focused child ticket under `nd-gv62` and wire it into this chain with `tk dep`:

- prerequisite: `tk dep <current-ticket> <new-prereq>`
- next follow-up: `tk dep <new-follow-up> <current-ticket>` and update later/sentinel deps as needed
- optional/speculative: add a tk note/link instead of unblocking the queue

Each OnePlus loop iteration should leave a tk note naming the evidence checked, the result, and the next ticket expected to become ready. Do not rely on stale docs, archive history, or ticket creation time for ordering.

For OnePlus UI/display/touch/app-navigation work, use and extend the reusable tool library in `docs/oneplus-debug-tools.md`. The baseline flake apps are `oneplus-screenshot`, `oneplus-touch`, and `oneplus-key`; new helpers should be one-shot, documented, dry-run-capable when they perform actions, and must not auto-commit.

## Golden Rules

### Formatting
- Formatting is handled by pre-commit hooks; do not instruct agents/users to run `nix fmt` or `nixfmt` for normal changes.
- Run `nix flake check` to validate

### Required Validation
- Do not report a Nix change as done until you have run at least one relevant validation command, or explicitly stated that you did not run validation.
- When iterating with `nr`, do **not** run `nix eval` first; it duplicates work and slows reboot-debug loops. Commit coherent changes, then run `nr` directly.
- For non-`nr` validation, prefer focused option/syntax checks. Use `nix eval .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath` only when you are not about to run `nr`.
- **Do not run Nix builds** (`nix build`, `nixos-rebuild build`, `nixos-rebuild switch`, `nix flake check`, or any command that realizes/builds Nix outputs) unless the user explicitly instructs you to build.
- **Do not rebuild or switch the current system yourself** unless the user explicitly instructs you to do so. When a change needs activation, report back that a rebuild/switch is needed and provide the appropriate command for the user to run.
- If the user explicitly requests a build, use a targeted build for host-specific changes such as `nix build .#nixosConfigurations.<host>.config.system.build.toplevel`; use `nix flake check` only for broad validation when requested.
- If you edit shell code inside a Nix indented string, escape shell parameter expansions like `${1:-default}` as `''${1:-default}` so Nix does not parse them as interpolation.
- When validation is skipped or blocked, say so clearly before claiming completion.

### Pipe Operator
Use the `pipe` experimental feature for improved readability. Prefer pipes over deeply nested function calls:

```nix
# ✅ Preferred - using pipe operator
pkgs.example
|> lib.enableFeature "foo"
|> lib.withConfig { bar = true; }

# ❌ Avoid - nested calls are harder to read
lib.withConfig { bar = true; } (lib.enableFeature "foo" pkgs.example)
```

### File Naming
- **Files**: kebab-case (`my-module.nix`)
- **Attributes**: camelCase (`myOption`)

### Home Manager Integration
Always use the `hm.` shortcut with the appropriate scope, never raw paths:

```nix
# ✅ Correct - Primary user only (most common)
hm.primary.programs.zsh.enable = true;

# ✅ Correct - All users (shared configuration)
hm.all.programs.git.enable = true;

# ✅ Correct - Specific user (when needed)
hm.beau.programs.git.userEmail = "beau@example.com";

# ❌ Wrong - Never use raw home-manager paths
home-manager.users.beau.programs.zsh.enable = true;
```

**Scope Reference:**
- `hm.primary.*` - Configuration for the primary user only (first user in the host's users list)
- `hm.all.*` - Configuration shared across all users on the host
- `hm.<username>.*` - Per-user configuration for a specific user

### Module Header
Use standard parameter format:

```nix
{ config, lib, pkgs, ... }:
{
  # configuration here
}
```

### Library Helpers
Use `lib.custom` utilities:

```nix
# Options
options.myModule.enable = lib.custom.mkBoolOpt false "Enable feature";
options.myModule.port = lib.custom.mkOpt lib.types.port 8080 "Port number";

# Quick enable/disable
services.tailscale = lib.custom.enabled;
```

## MCP Tool Usage

Use these MCP tools to validate your work:

### context7 - Library Documentation

Use for Nix patterns, library APIs, and best practices:

```
1. First resolve library ID: context7_resolve-library-id
2. Then query docs: context7_query-docs
```

### nixos - NixOS/Home Manager Options

Use for finding valid options and packages:

```
nixos_nix with:
- action: search
- source: nixos | home-manager | darwin
- type: packages | options | programs
- channel: 25.11 (preferred)
```

**Examples**:
- Find NixOS option: `action: search, source: nixos, type: options, query: "services.nginx"`
- Find HM option: `action: search, source: home-manager, type: options, query: "programs.zsh"`
- Find package: `action: search, source: nixos, type: packages, query: "ripgrep"`

See [specs/tooling.md](specs/tooling.md) for complete command reference.

## Opencode Agent Usage

Use the dedicated opencode subagents to keep the primary model's context clean:

- **@build-tests**: Run build/test commands (e.g., `nix build`, `nix flake check`) and return a short success/failure summary with only the relevant error snippets.
- **@code-search**: Read-only code lookup (glob/grep/read).
- **@github**: Git operations when explicitly requested.

## Security Constraints

### Absolute Rules

| Action                              | Allowed |
|-------------------------------------|---------|
| Reference `config.sops.secrets.*.path` | ✅ Yes |
| Tell user to run secret commands    | ✅ Yes |
| Run `sops` CLI commands             | ❌ **NEVER** |
| Access the private `sops-secrets` repo directly | ❌ **NEVER** |
| Read `.sops.yaml` in the private secrets repo | ❌ **NEVER** |
| Read files in the private secrets repo        | ❌ **NEVER** |
| Display any key material            | ❌ **NEVER** |

### When Secrets Are Needed

Instruct the user to:
1. Create/edit secrets: `ssh nas 'cd /home/beau/sops-secrets && sops secrets/<file>.yaml'`
2. Update SOPS config: `just gen-sops-yaml`
3. Re-encrypt after key changes: `just update-sops`

The agent must never inspect, list, grep, cat, or otherwise access the private `sops-secrets` repository itself. Only instruct the user which commands to run there.

When declaring module secrets, always set `sopsFile = lib.custom.sopsFileForModule __curPos.file;`. Do not use `sopsRootFile` from feature modules to reach across root secret files; `sopsFileForModule` is the repo convention that keeps secrets tied to the consuming module's root-specific SOPS file.

See [specs/secrets.md](specs/secrets.md) for patterns.

## Maintenance Protocol

### When to Update Documentation

Update these docs when you:
- Add a new host → Update [specs/hosts.md](specs/hosts.md) fleet table
- Add a new root → Update [specs/roots.md](specs/roots.md) roots table
- Change lib functions → Update [specs/modules.md](specs/modules.md) helpers section
- Modify module structure → Update relevant spec file
- Change tooling/commands → Update [specs/tooling.md](specs/tooling.md)

### What to Update

| Change Type               | Files to Update                            |
|---------------------------|-------------------------------------------|
| New host                  | `specs/hosts.md` (fleet table)            |
| New root                  | `specs/roots.md` (roots table)            |
| New module category       | `AGENTS.md` (directory table), `specs/modules.md` |
| New lib function          | `specs/modules.md` (helpers section)      |
| New just command          | `specs/tooling.md` (commands table)       |
| Workflow change           | `AGENTS.md` (relevant section)            |

### Validation

After documentation changes:
1. Ensure all cross-references are valid
2. Verify code examples are accurate
3. Run `nix flake check` (good practice)

## Quick Start for Common Tasks

### Adding a New Package

1. Find package: `nixos_nix action:search type:packages query:"<name>"`
2. Find appropriate module or create new one
3. Add to `environment.systemPackages` or `hm.home.packages`
4. Run `nix flake check`

### Adding a New Service

1. Read [specs/modules.md](specs/modules.md) for boilerplate
2. Find NixOS options: `nixos_nix action:search type:options query:"services.<name>"`
3. Create `modules/services/<name>/<root>.nix`
4. If secrets needed, see [specs/secrets.md](specs/secrets.md)

### Adding a New Host

1. Read [specs/hosts.md](specs/hosts.md) for full procedure
2. Create directory and files in `/hosts/<hostname>/`
3. Add entry to `modules/host-spec/all-hosts.nix`
4. Tell user to generate age keys and run `just gen-sops-yaml`

### Modifying Desktop Environment

1. Check host has `client` root in `all-hosts.nix`
2. Edit files in `modules/desktop/<wm>/`
3. Use `hm.primary.` for user-level config (dotfiles, settings, personal apps)
4. Use `hm.all.` only for configuration that should apply to every user
5. Use root-level for system config (services, packages)
