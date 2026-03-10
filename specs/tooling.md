# Tooling Specification

## Overview

This repository uses several tools for development, building, and deployment:
- **Just** - Command runner for common tasks
- **Nix Flakes** - Reproducible builds and dependency management
- **Pre-commit** - Automated code quality checks
- **Direnv** - Automatic environment loading

## Just Commands

The `justfile` provides shortcuts for common operations. Run `just` with no arguments to see all available commands.

### Flake Management

| Command       | Description                        |
|---------------|------------------------------------|
| `just update` | Update all flake inputs (flake.lock) |

### Building

| Command              | Description                                    |
|----------------------|------------------------------------------------|
| `just build <host>`  | Build NixOS configuration for specified host   |

### Deployment

| Command                    | Description                                        |
|----------------------------|----------------------------------------------------|
| `just deploy <host>`       | Deploy and switch to new configuration on remote host |
| `just deploy-test <host>`  | Dry-run deployment (test without activating)       |
| `just sync <user> <host> <path>` | Rsync repository to remote host            |

Some hosts have convenience wrappers:
- `just deploy-pi4` - Deploy to Raspberry Pi
- `just deploy-nas` - Deploy to NAS

### ISO / Installer

| Command           | Description                              |
|-------------------|------------------------------------------|
| `just iso`        | Build the custom NixOS installer ISO     |
| `just test-iso`   | Test the ISO in QEMU virtual machine     |
| `just iso-install`| Write ISO to a USB drive                 |

### Secrets Management

| Command              | Description                                          |
|----------------------|------------------------------------------------------|
| `just age-key`       | Generate a new Age key pair                          |
| `just gen-sops-yaml` | Regenerate `.sops.yaml` in the private `sops-secrets` repo |
| `just update-sops`   | Re-encrypt secrets in the private `sops-secrets` repo |

**Note**: Agents should instruct users to run these commands rather than running them directly.

## Development Shell

Enter the development environment:

```bash
nix develop
```

This provides:
- Node.js (for tooling)
- Pre-commit hooks (automatically installed)
- Any other development dependencies

### Direnv Integration

If you have direnv installed, the shell activates automatically when entering the directory. The `.envrc` file handles this.

## Pre-commit Hooks

Hooks are defined in `lib/checks.nix` and run automatically in the dev shell.

### Nix Formatting & Quality

| Hook              | Purpose                                    |
|-------------------|--------------------------------------------|
| `nixfmt-rfc-style`| Format Nix code according to RFC style     |
| `deadnix`         | Remove unused code and variables           |

### Shell Script Quality

| Hook        | Purpose                            |
|-------------|------------------------------------|
| `shellcheck`| Lint shell scripts for issues      |
| `shfmt`     | Format shell scripts consistently  |

### General Hygiene

| Hook                        | Purpose                                |
|-----------------------------|----------------------------------------|
| `check-added-large-files`   | Prevent accidentally committing large files |
| `check-merge-conflicts`     | Detect unresolved merge conflict markers |
| `detect-private-keys`       | Prevent committing private key material |
| `trim-trailing-whitespace`  | Remove trailing whitespace             |
| `end-of-file-fixer`         | Ensure files end with newline          |
| `forbid-submodules`         | Prevent git submodule usage            |

### Running Hooks Manually

```bash
# Run all hooks on all files
pre-commit run --all-files

# Run specific hook
pre-commit run nixfmt --all-files
```

## Flake Structure

### Inputs

The flake uses these primary inputs:

| Input             | Purpose                                    |
|-------------------|--------------------------------------------|
| `nixpkgs`         | Main package set (NixOS 25.11)             |
| `nixpkgsStable`   | Stable channel for specific packages       |
| `nixpkgsUnstable` | Unstable channel for bleeding edge         |
| `home-manager`    | User environment management                |
| `sops-nix`        | Secret management                          |
| `disko`           | Declarative disk partitioning              |
| `stylix`          | System-wide theming                        |
| `nixvim`          | Neovim configuration in Nix                |
| `nixos-hardware`  | Hardware-specific optimizations            |
| `pre-commit-hooks`| Pre-commit hook definitions                |

### Outputs

| Output              | Description                                    |
|---------------------|------------------------------------------------|
| `nixosConfigurations` | Auto-generated from `/hosts/` directories    |
| `formatter`         | `nixfmt-rfc-style` for `nix fmt`               |
| `checks`            | Pre-commit hooks for `nix flake check`         |
| `devShells.default` | Development shell with tooling                 |
| `lib.custom`        | Custom library functions extended onto `lib`   |

### How Hosts are Discovered

The flake automatically scans `/hosts/` and creates a `nixosConfiguration` for each subdirectory:

```nix
nixosConfigurations = builtins.listToAttrs (
  map (host: {
    name = host;
    value = nixpkgs.lib.nixosSystem {
      # ... configuration for host
    };
  }) (builtins.attrNames (builtins.readDir ./hosts))
);
```

## Validation Commands

### Check Flake Validity

```bash
nix flake check
```

This runs:
- Pre-commit hooks on all files
- Basic flake evaluation checks

### Build Without Deploying

```bash
just build <hostname>
# or directly:
nix build .#nixosConfigurations.<hostname>.config.system.build.toplevel
```

### Evaluate Without Building

```bash
nix eval .#nixosConfigurations.<hostname>.config.<option>
```

### Show Flake Info

```bash
nix flake show
nix flake metadata
```

## Common Workflows

### Adding a New Package

1. Find the package name using nixos MCP
2. Add to appropriate module
3. Run `nix flake check`
4. Build: `just build <hostname>`

### Updating Dependencies

```bash
just update        # Update all inputs
nix flake check    # Verify nothing broke
just build <host>  # Test build
```

### Testing Changes Locally

```bash
# Build and switch (on local machine)
sudo nixos-rebuild switch --flake .#<hostname>

# Build and test (creates boot entry but doesn't switch)
sudo nixos-rebuild test --flake .#<hostname>
```

### Deploying to Remote Host

```bash
# Dry run first
just deploy-test <hostname>

# Actually deploy
just deploy <hostname>
```

## Troubleshooting

### Flake Check Fails

1. Run `nix develop` to ensure hooks are installed
2. Run `pre-commit run --all-files` to see specific failures
3. For formatting issues: `nix fmt` will auto-fix

### Build Fails

1. Check error message for missing option/package
2. Use nixos MCP to verify option paths
3. Ensure file is named correctly for root system

### Deployment Fails

1. Verify network connectivity to host
2. Check that target host has the repository cloned
3. Ensure SSH keys are properly configured

## Related Specifications

- [Hosts](./hosts.md) - Host-specific build targets
- [Modules](./modules.md) - What gets built
- [Secrets](./secrets.md) - Secret management commands
- [Installer](./installer.md) - ISO building specifics
