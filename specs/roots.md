# Roots System Specification

## Overview

The "roots" system is the core mechanism for conditional module importing. Each host defines a list of roots, and only module files whose basename matches one of those roots (or the hostname itself) get imported.

This allows:
- Sharing common configuration across similar hosts
- Layering features progressively (minimal → common → specialized)
- Host-specific overrides without affecting other machines

## How `importAll` Works

The `lib.custom.importAll` function (defined in `lib/default.nix`) performs the following:

1. Takes parameters: `{ roots, host, extraSpecialArgs ? {}, useHost ? true }`
2. Recursively scans the entire `modules/` directory tree
3. For each `.nix` file found:
   - Extracts the basename (e.g., `common.nix` → `common`)
   - If basename matches any item in `roots` → **import it**
   - If basename matches `host` and `useHost` is true → **import it**
4. Returns a flattened list suitable for the `imports` attribute
5. Additionally injects Home Manager default configuration

### Example

For a host with `roots = ["minimal", "common", "work"]` and `host = "grill"`:

```
modules/cli/git/minimal.nix     → IMPORTED (matches "minimal")
modules/cli/git/common.nix      → IMPORTED (matches "common")
modules/cli/git/work.nix        → IMPORTED (matches "work")
modules/cli/git/gaming.nix      → NOT imported (no "gaming" root)
modules/cli/git/grill.nix       → IMPORTED (matches hostname)
modules/cli/git/nas.nix         → NOT imported (different host)
```

## Available Roots

| Root      | Purpose                                         | Typical Usage                        |
|-----------|-------------------------------------------------|--------------------------------------|
| `minimal` | Core system essentials, always required         | All hosts                            |
| `common`  | Standard features for interactive systems       | Most hosts (except iso)              |
| `network` | Network-connected services and configuration    | Hosts with network access            |
| `client`  | Desktop/GUI client features                     | Workstations with displays           |
| `server`  | Server-specific services (headless)             | NAS, remote servers                  |
| `main`    | Primary machine features, enhanced configs      | Main workstations and servers        |
| `work`    | Professional development tools                  | Development machines                 |
| `gaming`  | Gaming-specific packages and configuration      | Gaming-capable machines              |

## Root Hierarchy and Layering

Roots are designed to layer progressively:

```
minimal (base)
    └── common (interactive features)
            ├── network (network services)
            │       ├── client (desktop GUI)
            │       │       └── main + work + gaming (specialized)
            │       └── server (headless services)
            │               └── main (enhanced server)
            └── (no network - offline systems)
```

## File Naming Convention

Files must be named exactly as the root they target:

| Filename       | Imported When                                |
|----------------|----------------------------------------------|
| `minimal.nix`  | Host has `"minimal"` in roots                |
| `common.nix`   | Host has `"common"` in roots                 |
| `network.nix`  | Host has `"network"` in roots                |
| `client.nix`   | Host has `"client"` in roots                 |
| `server.nix`   | Host has `"server"` in roots                 |
| `main.nix`     | Host has `"main"` in roots                   |
| `work.nix`     | Host has `"work"` in roots                   |
| `gaming.nix`   | Host has `"gaming"` in roots                 |
| `grill.nix`    | Host is `"grill"` (hostname match)           |
| `nas.nix`      | Host is `"nas"` (hostname match)             |

## Root Selection Guide

When creating a new module or deciding where to place configuration:

### Use `minimal.nix` for:
- Boot configuration
- Essential system services
- Core user account setup
- Basic security settings

### Use `common.nix` for:
- Shell configuration
- Common CLI tools
- Fonts and locale
- Quality-of-life features

### Use `network.nix` for:
- Network management
- Tailscale/VPN
- SSH configuration
- Firewall rules

### Use `client.nix` for:
- Window manager/compositor
- Desktop applications
- Audio/video setup
- Input device configuration

### Use `server.nix` for:
- Headless services
- Docker/containers
- Web servers
- Database services

### Use `main.nix` for:
- Enhanced configurations for primary machines
- Resource-intensive features
- Full development environments

### Use `work.nix` for:
- IDE and editor configs
- Language toolchains
- Work-specific applications
- VPN for work

### Use `gaming.nix` for:
- Steam and game launchers
- Graphics driver tweaks
- Gaming peripherals
- Performance optimizations

### Use `<hostname>.nix` for:
- Machine-specific hardware quirks
- Unique service configurations
- Overrides that shouldn't affect other hosts

## Adding a New Root

If the existing roots don't fit your use case:

### Step 1: Define Semantic Meaning

Document what the new root represents and when it should be used.

### Step 2: Add to Relevant Hosts

Edit `modules/host-spec/all-hosts.nix`:

```nix
{
  grill = {
    # ...
    roots = [
      "minimal"
      "common"
      "newroot"  # Add new root
    ];
  };
}
```

### Step 3: Create Module Files

Create `<newroot>.nix` files in the appropriate module directories:

```nix
# modules/services/example/newroot.nix
{ config, lib, pkgs, ... }:
{
  # Configuration that applies when newroot is enabled
}
```

### Step 4: Update Documentation

Add the new root to this specification and update `AGENTS.md` if it represents a significant architectural addition.

## Debugging Root Issues

If a module isn't being imported:

1. **Check host's roots**: Look in `modules/host-spec/all-hosts.nix`
2. **Verify filename**: Must exactly match root name (e.g., `common.nix`, not `common-extra.nix`)
3. **Check directory**: File must be under `modules/` directory tree
4. **Review importAll**: The function only looks for exact basename matches

## Related Specifications

- [Hosts](./hosts.md) - Where roots are defined for each host
- [Modules](./modules.md) - How to structure files that get imported by roots
