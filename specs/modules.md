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

### Graphical Session Services

UWSM owns the graphical-session lifecycle on Hyprland hosts. Prefer an upstream
NixOS or Home Manager module for long-running session programs and attach custom
user services to `graphical-session.target`. Do not launch persistent processes
from Hyprland with `exec-once = ... &`; unmanaged processes are not restarted
and do not get a dedicated user journal.

A custom NixOS user service should normally use:

```nix
systemd.user.services.example = {
  wantedBy = [ "graphical-session.target" ];
  after = [ "graphical-session.target" ];
  partOf = [ "graphical-session.target" ];
  serviceConfig = {
    ExecStart = "${pkgs.example}/bin/example";
    Restart = "on-failure";
    RestartSec = 2;
  };
};
```

Use the equivalent Home Manager `Unit`, `Service`, and `Install` sections when
the application is user-owned. Keep compositor startup entries only for genuine
one-shot actions whose exit is expected, such as the initial autologin lock.
XDG autostart is acceptable when it is the application's canonical mechanism,
but each process must have exactly one startup owner.

Inspect the resulting session with:

```sh
systemctl --user list-dependencies graphical-session.target
systemctl --user status example.service
journalctl --user -u example.service
```

### Hosted Services and Optional TLS Passthrough

`modules/hosted-services/server.nix` owns `hostedServices` and imports the
shared Nginx ingress helper in `modules/services/nginx/tls-ingress.nix`.
Ordinary entries keep their existing HTTP reverse proxy, DNS and ACME behavior.

A backend that terminates its own TLS can opt into TCP/443 routing:

```nix
hostedServices = [
  {
    domain = "proxy.example.com";
    upstreamPort = toString config.custom.ports.assigned."example/tls";
    tlsPassthrough = true;
  }
];
```

`tlsPassthrough` defaults to false. Setting it to true defaults `doNginx` to
false and enables shared SNI routing while any passthrough entry exists.
Passthrough entries are public; do not combine them with `tailnet = true`,
`doNginx = true`, or `manageNginxListeners = true`. Upstreams receive raw TLS,
not PROXY headers. Hostname aliases are included in SNI routing.

`manageNginxListeners` defaults to `doNginx`. For an application such as Jitsi
whose module already owns its Nginx virtual host, set `doNginx = false` and
`manageNginxListeners = true`. This changes only that domain's listeners and
client-IP restoration while the TCP frontend is enabled; the application keeps
ownership of its locations and certificates. DNS-only records should leave it
false. Externally owned virtual hosts must use HTTPS and the entry's domain as
their Nginx virtual-host key.

Public and tailnet-only HTTPS backends are separate; the frontend's original
destination address gates private sites. Removing the last passthrough entry
removes all shared-ingress port requests and listener overrides, restoring
native Nginx listeners. No application-specific ingress logic belongs in a
proxy service module. See [tailscale-proxy.md](./tailscale-proxy.md) for the NAS
consumer, deployment caveats, and secret provisioning.

### Synchronized Application State

Primary fleet hosts expose `config.syncedState.root`, backed by the Syncthing
`state-sync` folder. Application modules must opt in by configuring their native
state or data directory beneath this root:

```nix
let
  synchronizedSessions = "${config.syncedState.root}/pi/sessions";
  nativeSessions = "${config.hostSpec.home}/.pi/agent/sessions";
in
{
  systemd.mounts = [
    {
      what = synchronizedSessions;
      where = nativeSessions;
      type = "none";
      options = "bind";
      wantedBy = [ "multi-user.target" ];
    }
  ];
}
```

Only synchronize file-oriented state that is safe for whole-file replication.
Do not place credentials, caches, sockets, lock files, databases, or state that
will be written concurrently by multiple hosts under this root. Prefer native
application settings; use an application-specific migration adapter when an
application cannot configure its state location. Pi's migration, activation,
rollback, and cross-host acceptance procedure is documented in
[`pi-session-sync.md`](./pi-session-sync.md).

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
