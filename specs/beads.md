# Beads Service

## Target Architecture

- `nas` runs the single persistent Dolt SQL server used by Beads.
- The server listens only on the tailnet address and port `3307`.
- Client hosts (`t480`, `grill`, and local use on `nas`) connect to that server with `BEADS_DOLT_*`.
- Live Dolt state does not live inside project trees and should not be synced with Syncthing.

## Nix Modules

- `modules/services/beads/nas.nix`
  Runs the central Dolt SQL server on `nas`.
- `modules/cli/beads/main.nix`
  Wraps `bd` so every invocation uses the central NAS server.

## Runtime Paths

- Server data dir: `/var/lib/beads-dolt`
- Client password file: `~/.config/beads/dolt-password`

The central data dir is intentionally outside any synced project checkout. Do not Syncthing this directory.

## Tailnet Exposure

- DNS name: `beads-db.bepis.lol`
- Binding: `config.hostSpec.tailIP`
- Firewall: only `tailscale0` is opened for port `3307`

The hosted-services layer is used only for split-DNS publication. The Dolt SQL server itself is a systemd service, not an nginx-backed HTTP service.

## Secrets

- Server secret: `beads/dolt-root-password`
- Client secret: `beads/dolt-password`

Keep the client and server passwords aligned. The server uses the password to initialize `root@'%'` on first boot against an empty privilege store.

## Migration Plan

### Goal

Move the existing coordinator Beads database off `repos/coordinator/.beads/dolt` and onto the central NAS service without losing issue history.

### Source Data

Current coordinator Beads data lives in:

- `coordinator/.beads/dolt/coordinator`

Do not migrate the old `.doltcfg/privileges.db`. Let the NAS service create a fresh remote-capable privilege store.

### Cutover Steps

1. Deploy the NAS service but do not import data yet.
2. Stop local writes to the coordinator Beads database.
3. Stop any local Dolt server that is still using the old coordinator data dir.
4. On `nas`, stop the central service:

```bash
sudo systemctl stop beads-dolt.service
```

5. Prepare the new `/var` data dir and copy the coordinator database payload into place:

```bash
sudo mkdir -p /var/lib/beads-dolt
sudo rm -rf /var/lib/beads-dolt/coordinator
sudo cp -a /home/beau/documents/projects/coordinator/.beads/dolt/coordinator /var/lib/beads-dolt/
sudo chown -R beau:users /var/lib/beads-dolt
```

Do not copy the old `.doltcfg/privileges.db`; the NAS service should recreate the privilege store in `/var/lib/beads-dolt/.doltcfg`.

6. Start the NAS service:

```bash
sudo systemctl start beads-dolt.service
```

7. From a client host, verify the remote connection:

```bash
bd dolt show
bd list
```

8. Once the remote DB is confirmed, remove stale local runtime state from project trees so clients cannot silently fall back to local Dolt state:

```bash
rm -rf .beads/dolt .beads/dolt-server.port .beads/dolt-server.lock .beads/dolt-server.log
```

Keep `.beads/metadata.json` only if the repo still needs local Beads identity/config; otherwise reinitialize against the remote server after backup.

## Syncthing

Do not sync live Dolt runtime state. The `documents` Syncthing folder should install a local `.stignore` that excludes:

- `.beads/dolt/`
- `.beads/dolt-server.port`
- `.beads/dolt-server.lock`
- `.beads/dolt-server.log`

If any host later uses Beads shared-server mode locally, also exclude:

- `~/.beads/shared-server/`

## Validation

After deployment and migration, validate from each host:

```bash
bd dolt test
bd list
bd ready
```
