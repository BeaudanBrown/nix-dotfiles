# Module Development Specification

## Overview

Modules are the building blocks of this NixOS configuration. They are organized by category, named by root, and automatically imported based on each host's enabled roots.

## Directory Structure

```
modules/
├── apps/             # GUI applications (Brave, Obsidian, etc.)
├── cli/              # Command-line tools (git, zsh, tmux)
├── desktop/          # Window managers, compositors (Hyprland, Waybar)
├── gaming/           # Gaming-specific (Steam, Lutris)
├── hardware/         # Hardware configuration (GPU, audio, bluetooth)
├── home-manager/     # Global Home Manager settings
├── host-spec/        # Central host registry and hostSpec definition
├── hosted-services/  # Web services, reverse proxies (Authentik, etc.)
├── nix/              # Nix daemon, flake settings, garbage collection
├── scripts/          # Custom shell scripts as packages
├── security/         # SOPS, PAM, sudo, polkit
├── services/         # System services (Docker, SSH, Tailscale)
├── system/           # Core system (boot, networking, fonts, locale)
├── tools/            # Development utilities (direnv, just)
├── triage/           # Temporary/experimental configurations
└── user/             # User account configuration
```

## Module File Structure

Each feature typically has its own directory with root-specific files:

```
modules/cli/git/
├── minimal.nix       # Basic git config (all hosts)
├── common.nix        # Enhanced config (interactive hosts)
├── work.nix          # Work-specific settings
└── grill.nix         # Overrides for grill host only
```

## Standard Module Template

```nix
{ config, lib, pkgs, ... }:
{
  # ══════════════════════════════════════════════════════════
  # System-level configuration (NixOS options)
  # ══════════════════════════════════════════════════════════

  programs.git.enable = true;

  environment.systemPackages = with pkgs; [
    git
    git-lfs
  ];

  # ══════════════════════════════════════════════════════════
  # User-level configuration (Home Manager via hm. shortcut)
  # ══════════════════════════════════════════════════════════

  hm = {
    programs.git = {
      enable = true;
      userName = config.hostSpec.userFullName;
      userEmail = config.hostSpec.email;

      extraConfig = {
        init.defaultBranch = "main";
        pull.rebase = true;
      };
    };
  };
}
```

## The `hm.` Shortcut

### What It Is

The `hm` attribute is a custom NixOS option that provides a shortcut to Home Manager configuration. Instead of writing:

```nix
home-manager.users.${config.hostSpec.username}.programs.zsh = { ... };
```

You write:

```nix
hm.programs.zsh = { ... };
```

### How It Works

Defined in `modules/host-spec/minimal.nix`:

```nix
options.hm = lib.mkOption {
  type = lib.types.attrsOf lib.types.anything;
  default = { };
  description = "Shortcut to home-manager config";
};

config = {
  home-manager.users.${config.hostSpec.username} = config.hm;
};
```

### Why Use It

- **Cleaner code**: Avoids deep nesting
- **Automatic username**: Uses `hostSpec.username` automatically
- **Proper merging**: Multiple modules can contribute to `hm` and values merge correctly

### Usage Examples

```nix
# Shell configuration
hm.programs.zsh = {
  enable = true;
  shellAliases = { ll = "ls -la"; };
};

# XDG directories
hm.xdg = {
  enable = true;
  userDirs.enable = true;
};

# Dotfiles
hm.home.file.".config/app/config.toml".text = ''
  setting = "value"
'';

# User services
hm.services.syncthing.enable = true;

# User packages
hm.home.packages = with pkgs; [ ripgrep fd ];
```

## Library Helpers

The `lib.custom` namespace provides utilities for module development:

### Option Creation

```nix
# Create a typed option with description
options.myModule.port = lib.custom.mkOpt lib.types.port 8080 "Port to listen on";

# Create option without description
options.myModule.host = lib.custom.mkOpt' lib.types.str "localhost";

# Create boolean options
options.myModule.enable = lib.custom.mkBoolOpt false "Enable my module";
options.myModule.debug = lib.custom.mkBoolOpt' false;
```

### Enable/Disable Shortcuts

```nix
# Instead of: services.tailscale.enable = true;
services.tailscale = lib.custom.enabled;

# Instead of: services.nginx.enable = false;
services.nginx = lib.custom.disabled;
```

### Path Helpers

```nix
# Get path relative to repository root
lib.custom.relativeToRoot "modules/apps"  # → /path/to/repo/modules/apps
```

## Creating a New Module

### Step 1: Choose the Category

Map your feature to the appropriate directory:

| Feature Type          | Directory              |
|-----------------------|------------------------|
| GUI application       | `modules/apps/`        |
| CLI tool              | `modules/cli/`         |
| Desktop environment   | `modules/desktop/`     |
| System service        | `modules/services/`    |
| Hardware config       | `modules/hardware/`    |
| Development tool      | `modules/tools/`       |

### Step 2: Create the Directory

```
modules/<category>/<feature>/
```

### Step 3: Create Root-Specific Files

Decide which roots should include your feature:

```nix
# modules/apps/myapp/common.nix - For all interactive hosts
{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.myapp ];

  hm.programs.myapp = {
    enable = true;
  };
}
```

```nix
# modules/apps/myapp/work.nix - Additional work-specific config
{ ... }:
{
  hm.programs.myapp.settings = {
    workProfile = true;
  };
}
```

### Step 4: Test

```bash
nix flake check
just build <hostname>
```

## Module Patterns

### Conditional Configuration

```nix
{ config, lib, ... }:
{
  config = lib.mkIf config.hostSpec.wifi {
    networking.wireless.enable = true;
  };
}
```

### Accessing hostSpec

```nix
{ config, ... }:
{
  # Use hostSpec for dynamic values
  networking.hostName = config.hostSpec.hostName;

  hm.programs.git = {
    userName = config.hostSpec.userFullName;
    userEmail = config.hostSpec.email;
  };
}
```

### Defining Custom Options

```nix
{ config, lib, ... }:
let
  cfg = config.custom.myFeature;
in
{
  options.custom.myFeature = {
    enable = lib.custom.mkBoolOpt false "Enable my feature";
    port = lib.custom.mkOpt lib.types.port 8080 "Port number";
  };

  config = lib.mkIf cfg.enable {
    services.myFeature.port = cfg.port;
  };
}
```

### Importing External Files

```nix
{ ... }:
{
  hm.programs.zsh.initExtra = builtins.readFile ./zshrc-extra.sh;

  hm.home.file.".config/app/config.toml".source = ./config.toml;
}
```

## Anti-Patterns to Avoid

### ❌ Don't use raw home-manager path

```nix
# Wrong
home-manager.users.beau.programs.zsh = { };

# Correct
hm.programs.zsh = { };
```

### ❌ Don't hardcode usernames

```nix
# Wrong
users.users.beau = { };

# Correct
users.users.${config.hostSpec.username} = { };
```

### ❌ Don't create files outside module directories

```nix
# Wrong - creating modules/myfile.nix at root of modules/

# Correct - create in appropriate category
modules/tools/mytool/common.nix
```

### ❌ Don't use incorrect root filenames

```nix
# Wrong
modules/cli/git/my-common-config.nix  # Won't be imported!

# Correct
modules/cli/git/common.nix
```

## Validation with MCP Tools

When creating or modifying modules, use MCP tools to validate:

### NixOS Options

```
Use nixos MCP with action: search, source: nixos, type: options
to find valid NixOS options
```

### Home Manager Options

```
Use nixos MCP with action: search, source: home-manager, type: options
to find valid Home Manager options
```

### Package Names

```
Use nixos MCP with action: search, source: nixos, type: packages
to find correct package names
```

## Related Specifications

- [Roots](./roots.md) - How files get imported based on roots
- [Hosts](./hosts.md) - Where roots are defined
- [Secrets](./secrets.md) - How to reference secrets in modules
