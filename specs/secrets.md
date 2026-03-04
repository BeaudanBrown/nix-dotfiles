# Secrets Management Specification

## Overview

Secrets are managed using [SOPS](https://github.com/getsops/sops) with Age encryption. This allows secrets to be stored encrypted in the repository and decrypted at build/runtime on authorized hosts.

**⚠️ CRITICAL: Agents must NEVER directly interact with secrets or SOPS commands.**

## Agent Constraints

| Action                                    | Allowed |
|-------------------------------------------|---------|
| Reference `config.sops.secrets.<name>.path` in modules | ✅ Yes |
| Tell user to create/edit secrets          | ✅ Yes |
| Tell user to run `just update-sops`       | ✅ Yes |
| Run `sops` CLI commands                   | ❌ **NEVER** |
| Read `.sops.yaml`                         | ❌ **NEVER** |
| Read files in `secrets/` directory        | ❌ **NEVER** |
| Display or log any key material           | ❌ **NEVER** |

## Directory Structure

```
secrets/
├── common.yaml           # Secrets for common root
├── work.yaml             # Secrets for work root
├── server.yaml           # Secrets for server root
├── <module-name>.yaml    # Module-specific secrets
└── ...
```

## Referencing Secrets in Modules

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
    sopsFile = lib.custom.sopsRootFile "server";  # → secrets/server.yaml
  };
}
```

### Using Module-Based Secret Files

```nix
{ config, lib, ... }:
{
  # If this file is modules/services/nginx/common.nix
  # This resolves to secrets/common.yaml
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
| `sopsRootFile "common"`                 | `secrets/common.yaml`   |
| `sopsRootFile "work"`                   | `secrets/work.yaml`     |
| `sopsFileForModule ./common.nix`        | `secrets/common.yaml`   |
| `sopsFileForModule ./myservice.nix`     | `secrets/myservice.yaml`|

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
> `sops secrets/<filename>.yaml`
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

1. **Secret file exists**: `secrets/<name>.yaml` must exist
2. **Key exists in file**: The YAML key path must match
3. **Host has access**: Host's age key must be in `.sops.yaml` recipients
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
