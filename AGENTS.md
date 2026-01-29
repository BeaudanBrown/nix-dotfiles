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
| `/secrets/`          | SOPS-encrypted secrets (DO NOT ACCESS)               |
| `/specs/`            | Detailed technical specifications                    |
| `/nixos-installer/`  | Custom installer flake                               |

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

## Golden Rules

### Formatting
- Use `nixfmt-rfc-style` (auto-enforced by pre-commit)
- Run `nix flake check` to validate

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
Always use the `hm.` shortcut, never raw paths:

```nix
# ✅ Correct
hm.programs.zsh.enable = true;

# ❌ Wrong
home-manager.users.beau.programs.zsh.enable = true;
```

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

## Security Constraints

### Absolute Rules

| Action                              | Allowed |
|-------------------------------------|---------|
| Reference `config.sops.secrets.*.path` | ✅ Yes |
| Tell user to run secret commands    | ✅ Yes |
| Run `sops` CLI commands             | ❌ **NEVER** |
| Read `.sops.yaml`                   | ❌ **NEVER** |
| Read files in `secrets/`            | ❌ **NEVER** |
| Display any key material            | ❌ **NEVER** |

### When Secrets Are Needed

Instruct the user to:
1. Create/edit secrets: `sops secrets/<file>.yaml`
2. Update SOPS config: `just gen-sops-yaml`
3. Re-encrypt after key changes: `just update-sops`

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
3. Use `hm.` for user-level config (dotfiles, settings)
4. Use root-level for system config (services, packages)
