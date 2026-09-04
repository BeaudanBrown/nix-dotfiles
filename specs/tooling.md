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

### Grill Local LLM

Network hosts install a `local-llm` lifecycle command for the Tailnet-only
llama.cpp router on Grill:

| Command | Description |
|---------|-------------|
| `local-llm up` | Start the router and wait for its health endpoint |
| `local-llm warm` | Start the router and load the default model with a tiny request |
| `local-llm down` | Stop the router and release its resources |
| `local-llm restart` | Restart the router and wait until it is healthy |
| `local-llm status` | Show the systemd and endpoint status |
| `local-llm health` | Query the router health endpoint |
| `local-llm logs` | Follow the Grill service journal |
| `local-llm verify-model` | Perform an explicit full SHA-256 verification |

The service is provisioned but not started at boot. Model metadata pins an immutable Hugging Face commit, LFS SHA-256, and byte size. A dedicated model identity downloads the exact GGUF into `/var/lib/local-llm-models`, verifies its hash, and atomically publishes it with a verification receipt. Normal starts validate the configuration-bound receipt, file metadata, ownership, permissions, and size without hashing the complete model again. A missing or stale receipt triggers one full verification; `local-llm verify-model` requests one explicitly. The inference identity has read-only model access. The first upgraded start adopts and verifies the existing cache without downloading a second copy. The router receives only the verified local path, never mutable `main` metadata. Text-only profiles disable automatic `mmproj` downloads. Initial preparation may keep service startup active for up to one hour. Loaded model state sleeps after its configured idle interval and wakes on the next inference request.

Neovim keeps editor and project R ownership separate. The diagnostics-only `r_language_server` uses an absolute host-owned R wrapper containing `languageserver`, so direnv project shells cannot shadow it. R.nvim intentionally continues to use the active project R for interactive work and target packages. Air uses its pinned absolute executable at warning log level; editor-only packages do not become analysis dependencies.

Use `pi-local` for a context-efficient local coding session. The host-owned
launcher selects Grill's local model and delegates to pi-harness's `pi-r-local`
adapter. The adapter disables general extension, skill, and project-context
discovery, explicitly loads only the pi-r extension and compact pi-r skill, and
starts with the lean read/search/edit tool surface. Pi-r remains inactive with
only `/r` until explicitly started; constrained phase tools can then replace and
later restore the lean surface. The dedicated Pi configuration uses a 4K
compaction reserve and keeps 6K recent tokens; normal `pi` sessions retain the
full harness and their existing settings.

Managed Matrix project creation uses the host-owned `tmux_project managed
project-create` operation. It accepts only a configured root key, a safe
immediate-child workspace name, a bounded creation key, and an explicit retry
flag. The operation creates no scaffold, task, remote, or publication: it uses a
deterministic private staging directory, initializes local Git on `main`, stores
the creation key in local Git metadata, and atomically publishes the directory.
An exact retry can recover recognized staging phases or a matching completed
repository; symlinks, foreign state, ownership mismatches, and conflicting Git
identity fail unchanged.

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

### Encrypted Fleet Installer

| Command | Description |
|---------|-------------|
| `just installer-usb` | Interactively provision an encrypted fleet installer USB |
| `just test-installer` | Run fast package, rekey, and host-evaluation checks |
| `just test-installer-e2e-provision` | Provision and cache an encrypted QEMU USB |
| `just test-installer-e2e-install` | Install a synthetic target from a cached USB snapshot |
| `just test-installer-e2e` | Run the complete rootless QEMU workflow |

See [Installer](./installer.md) for the architecture and physical workflow.

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

Formatting and lint cleanup are handled by the pre-commit hooks. Do not document `nix fmt`/`nixfmt` as a normal manual workflow.

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
| `formatter`         | Nix formatter exposed for editor/hook integration |
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
3. Let the configured hooks apply formatting/lint fixes

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
