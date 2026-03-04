# Host Configuration Specification

## Overview

Hosts represent individual machines in the NixOS fleet. Each host has:
- A directory in `/hosts/<hostname>/` containing hardware and entry-point configuration
- A central registry entry in `modules/host-spec/all-hosts.nix` defining metadata and enabled roots

The flake automatically discovers hosts by scanning the `/hosts/` directory - any subdirectory becomes a valid `nixosConfiguration`.

## Current Fleet

| Host     | Purpose              | Username   | Roots                                                    |
|----------|----------------------|------------|----------------------------------------------------------|
| grill    | Primary desktop      | beau       | minimal, common, network, client, main, work, gaming     |
| t480     | ThinkPad T480 laptop | beau       | minimal, common, network, client, main, work, gaming     |
| laptop   | Standard laptop      | beau       | minimal, common, network, main, work                     |
| nas      | Home server/NAS      | beau       | minimal, common, network, main, server                   |
| pi4      | Raspberry Pi 4       | beau       | minimal, common, network, client                         |
| brick    | Remote server        | mikaerem   | minimal, common, network, server                         |
| bottom   | Minimal node         | beau       | minimal, common                                          |
| iso      | Installer image      | nixos      | minimal                                                  |

## Host Directory Structure

Each host directory contains:

```
hosts/<hostname>/
├── default.nix   # Main entry point
└── hardware.nix  # Hardware-specific configuration (disko, kernel, boot)
```

### `default.nix` Template

```nix
{
  lib,
  inputs,
  ...
}:
let
  # Import central host registry
  allHosts = import ../../modules/host-spec/all-hosts.nix;
  host = "hostname";  # Must match directory name
  inherit (allHosts.${host}) roots;
in
{
  imports =
    [
      ./hardware.nix
      inputs.sops-nix.nixosModules.sops
      inputs.nixvim.nixosModules.nixvim
      inputs.stylix.nixosModules.stylix
      inputs.disko.nixosModules.disko
      inputs.home-manager.nixosModules.home-manager
    ]
    ++ (lib.custom.importAll { inherit host roots; });
}
```

### `hardware.nix` Template

```nix
{
  lib,
  config,
  pkgs,
  modulesPath,
  ...
}:
{
  # Disko disk layout
  disko.devices = {
    disk.main = {
      device = "/dev/nvme0n1";
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          # Define partitions here
        };
      };
    };
  };

  # Kernel modules
  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" ];
  boot.kernelModules = [ "kvm-amd" ];  # or kvm-intel

  # Hardware-specific settings
  hardware.cpu.amd.updateMicrocode = true;  # or intel
}
```

## hostSpec Attributes

The `hostSpec` option is defined in `modules/host-spec/minimal.nix` and populated from `all-hosts.nix`. Available attributes:

| Attribute      | Type    | Description                                      |
|----------------|---------|--------------------------------------------------|
| `hostName`     | string  | System hostname                                  |
| `username`     | string  | Primary user account name                        |
| `email`        | string  | User's email address (for git, etc.)             |
| `userFullName` | string  | Full name for user account                       |
| `tailIP`       | string  | Tailscale IP address (optional)                  |
| `wifi`         | bool    | Whether to enable WiFi-related modules           |
| `ageHostKey`   | string  | Public Age key for host-level secret decryption  |
| `ageUserKey`   | string  | Public Age key for user-level secret decryption  |
| `roots`        | list    | List of enabled module roots                     |

### Accessing hostSpec in Modules

```nix
{ config, ... }:
{
  # Access any hostSpec attribute
  networking.hostName = config.hostSpec.hostName;

  # Conditional based on hostSpec
  services.wifi.enable = config.hostSpec.wifi;

  # Use username for paths
  home-manager.users.${config.hostSpec.username} = { };  # Or use hm. shortcut
}
```

## Adding a New Host

### Step 1: Create Host Directory

```bash
mkdir -p hosts/<hostname>
```

### Step 2: Add Entry to Central Registry

Edit `modules/host-spec/all-hosts.nix`:

```nix
{
  # ... existing hosts ...

  newhost = {
    hostName = "newhost";
    username = "beau";
    email = "your@email.com";
    userFullName = "Your Name";
    tailIP = "100.64.x.x";  # Optional
    wifi = true;            # Or false
    ageHostKey = "";        # Generated in step 4
    ageUserKey = "";        # Generated in step 4
    roots = [
      "minimal"
      "common"
      # Add other roots as needed
    ];
  };
}
```

### Step 3: Create Configuration Files

Create `hosts/<hostname>/default.nix` and `hosts/<hostname>/hardware.nix` using the templates above.

### Step 4: Generate Age Keys

Ask the user to:
1. Generate host age key on the target machine
2. Generate user age key for the primary user
3. Add the public keys to the `all-hosts.nix` entry
4. Run `just gen-sops-yaml` to update SOPS configuration

### Step 5: Build and Test

```bash
just build <hostname>
```

## Modifying Host Configuration

| Change Type              | Where to Edit                                           |
|--------------------------|---------------------------------------------------------|
| Roots (enable features)  | `modules/host-spec/all-hosts.nix`                       |
| Hardware settings        | `hosts/<hostname>/hardware.nix`                         |
| Host-specific overrides  | Create `<hostname>.nix` in relevant module directory    |
| User metadata            | `modules/host-spec/all-hosts.nix`                       |

## Host-Specific Module Overrides

To create configuration that only applies to one host, create a file named `<hostname>.nix` in the relevant module directory:

```
modules/services/nginx/grill.nix    # Only imported for grill
modules/desktop/hyprland/t480.nix   # Only imported for t480
```

The `importAll` function automatically discovers and imports these files for the matching host.

## Related Specifications

- [Roots System](./roots.md) - Understanding which modules get imported
- [Modules](./modules.md) - How to structure module files
- [Secrets](./secrets.md) - Managing host-specific secrets
