# Secrets Management Specification

## Overview

Secrets are managed using [SOPS](https://github.com/getsops/sops) with Age encryption. Encrypted secret files and `.sops.yaml` live in the private `sops-secrets` repository, while this repo references them through helper functions and a flake input.

**⚠️ CRITICAL: Agents must NEVER directly interact with secrets or SOPS commands.**

## Agent Constraints

| Action                                    | Allowed |
|-------------------------------------------|---------|
| Reference `config.sops.secrets.<name>.path` in modules | ✅ Yes |
| Tell user to create/edit secrets          | ✅ Yes |
| Tell user to run `just update-sops`       | ✅ Yes |
| Run `sops` CLI commands                   | ❌ **NEVER** |
| Access the private `sops-secrets` repo directly | ❌ **NEVER** |
| Read `.sops.yaml` in the private secrets repo | ❌ **NEVER** |
| Read files in the private secrets repo        | ❌ **NEVER** |
| Display or log any key material           | ❌ **NEVER** |

Agents must never inspect, list, grep, cat, or otherwise access the private `sops-secrets` repository itself. They may only instruct the user which commands to run there.

## Directory Structure

Private repo layout:

```text
sops-secrets/
├── .sops.yaml
└── secrets/
    ├── common.yaml
    ├── work.yaml
    ├── server.yaml
    ├── <module-name>.yaml
    └── ...
```

## Referencing Secrets in Modules

Use the consumer to decide where a secret should live:

- If the consumer is a user-space tool managed by Home Manager, prefer HM `sops-nix`.
- If the consumer is a NixOS service or other system-owned configuration, keep it in NixOS `sops-nix`.
- A path under `/home/...` does not by itself mean the secret should move to Home Manager.

### Basic Pattern

```nix
{ config, lib, ... }:
{
  # Declare the secret
  sops.secrets.my-api-key = {
    sopsFile = lib.custom.sopsFileForModule ./common.nix;
  };

  # Use the secret path in configuration
  services.myservice = {
    apiKeyFile = config.sops.secrets.my-api-key.path;
  };
}
```

### Using Root-Based Secret Files

```nix
{ config, lib, ... }:
{
  sops.secrets.database-password = {
    sopsFile = lib.custom.sopsRootFile "server";  # → private repo: secrets/server.yaml
  };
}
```

### Using Module-Based Secret Files

```nix
{ config, lib, ... }:
{
  # If this file is modules/services/nginx/common.nix
  # This resolves to private repo: secrets/common.yaml
  sops.secrets.nginx-cert = {
    sopsFile = lib.custom.sopsFileForModule ./common.nix;
  };
}
```

### Secret Options

```nix
sops.secrets.my-secret = {
  sopsFile = lib.custom.sopsRootFile "common";

  # Optional: Override the key path in the YAML file
  key = "path/to/key/in/yaml";

  # Optional: Set file permissions
  mode = "0400";

  # Optional: Set owner (defaults to root)
  owner = config.hostSpec.username;
  group = "users";

  # Optional: Restart service when secret changes
  restartUnits = [ "myservice.service" ];
};
```

## Secret File Convention

The helper functions map to secret files as follows:

| Helper                                  | Resolves To             |
|-----------------------------------------|-------------------------|
| `sopsRootFile "common"`                 | `sops-secrets/secrets/common.yaml`   |
| `sopsRootFile "work"`                   | `sops-secrets/secrets/work.yaml`     |
| `sopsFileForModule ./common.nix`        | `sops-secrets/secrets/common.yaml`   |
| `sopsFileForModule ./myservice.nix`     | `sops-secrets/secrets/myservice.yaml`|

## Common Patterns

### Environment File for Services

```nix
{ config, lib, ... }:
{
  sops.secrets.myservice-env = {
    sopsFile = lib.custom.sopsRootFile "server";
  };

  services.myservice = {
    enable = true;
    environmentFile = config.sops.secrets.myservice-env.path;
  };
}
```

### SSH Keys

```nix
{ config, lib, ... }:
{
  sops.secrets.ssh-private-key = {
    sopsFile = lib.custom.sopsRootFile "common";
    owner = config.hostSpec.username;
    path = "/home/${config.hostSpec.username}/.ssh/id_ed25519";
    mode = "0600";
  };
}
```

### Database Passwords

```nix
{ config, lib, ... }:
{
  sops.secrets.postgres-password = {
    sopsFile = lib.custom.sopsRootFile "server";
    owner = "postgres";
  };

  services.postgresql = {
    enable = true;
    # Use the secret in initialization
    initialScript = pkgs.writeText "init.sql" ''
      ALTER USER postgres PASSWORD '$(cat ${config.sops.secrets.postgres-password.path})';
    '';
  };
}
```

### API Keys

```nix
{ config, lib, ... }:
{
  sops.secrets.api-key = {
    sopsFile = lib.custom.sopsRootFile "work";
    owner = config.hostSpec.username;
  };

  hm.home.sessionVariables = {
    # Note: This exposes path, not the actual secret
    API_KEY_FILE = config.sops.secrets.api-key.path;
  };
}
```

## When User Intervention is Required

Agents should instruct users to perform these actions:

### Adding a New Secret

Tell the user:
> "Please add the secret to the appropriate SOPS file by running:
> `ssh nas 'cd /home/beau/sops-secrets && sops secrets/<filename>.yaml'`
> and adding a key named `<key-name>` with your secret value."

### Updating SOPS Configuration

Tell the user:
> "After modifying host keys in `all-hosts.nix`, please run:
> `just gen-sops-yaml`
> to regenerate the SOPS configuration."

### Re-encrypting Secrets After Key Changes

Tell the user:
> "After adding new hosts or rotating keys, please run:
> `just update-sops`
> to re-encrypt all secrets with the updated key set."

### Generating Age Keys

Tell the user:
> "To generate a new Age key for a host, please run:
> `just age-key`
> and add the public key to the host's entry in `all-hosts.nix`."

## Troubleshooting Guide

When secrets aren't working, guide users to check:

1. **Secret file exists**: `sops-secrets/secrets/<name>.yaml` must exist
2. **Key exists in file**: The YAML key path must match
3. **Host has access**: Host's age key must be in the private repo's `.sops.yaml` recipients
4. **SOPS config updated**: `just gen-sops-yaml` may need to be run

## Security Best Practices

1. **Principle of least privilege**: Only give hosts access to secrets they need
2. **Use specific secret files**: Don't put all secrets in one file
3. **Set restrictive permissions**: Use `mode = "0400"` when possible
4. **Specify owners**: Always set appropriate `owner` for user secrets
5. **Never log secrets**: Don't use secrets in places that might be logged

## Related Specifications

- [Hosts](./hosts.md) - Where age keys are defined for each host
- [Modules](./modules.md) - How to structure modules that use secrets
- [Tooling](./tooling.md) - Just commands for secret management
