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

The lightweight router starts at boot and loads models only on demand. Model metadata pins an immutable Hugging Face commit, LFS SHA-256, and byte size. A dedicated model identity downloads the exact GGUF into `/var/lib/local-llm-models`, verifies its hash, and atomically publishes it with a verification receipt. Normal starts validate the configuration-bound receipt, file metadata, ownership, permissions, and size without hashing the complete model again. A missing or stale receipt triggers one full verification; `local-llm verify-model` requests one explicitly. The inference identity has read-only model access. The first upgraded start adopts and verifies the existing cache without downloading a second copy. The router receives only the verified local path, never mutable `main` metadata. Text-only profiles disable automatic `mmproj` downloads. Initial preparation may keep service startup active for up to one hour. Loaded model state sleeps after its configured idle interval while the router stays available, then wakes on the next inference request.

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

### Native Pi picker and optional Matrix bridge (#164, staged replacement)

Harness epic #160 / ADR 0003 supersedes the managed platform. #172's separately
approved migration-only activation completed on grill/NAS using downstream
`3faed95` and published harness `7f32929`. Both native ledgers and frozen backups
were verified; the privileged NAS original/account byte comparison also passed.
Newer grill histories must be retained; pending legacy account work stays held.
This normal source now carries the same temporary adapter and harness pin while
preserving newer unrelated host/tooling changes.

**Build preparation is not activation or live acceptance.** The normal held
baseline `8a48b3d` retains `startAfterMigration = false` on both hosts. This isolated
[grill startup candidate](./pi-grill-startup-172.md) permits grill's host-wide bridge
only after separate activation approval; NAS remains held. Both hosts retain
`holdSynchronization = true`. Synchronization restoration and live canaries
remain separately approved.
See the [temporary cutover runbook](./pi-native-cutover-172.md). Existing completion
records are revalidated without recapturing/importing old history; do not create
new permits or rerun first-migration maintenance commands.

The progressive picker starts fzf before discovery. Ordinary sessions/raw paths
remain usable independently of Pi history, the optional bridge, Matrix, NAS,
coordinators, account setup or Git metadata for a **native session**. Raw repository
navigation still validates Git on Enter. Path-only cache data under
`$XDG_CACHE_HOME/tmux-project/paths.json` is disposable; no native/Matrix lifecycle
authority is cached there.

The sole Pi seam is `pi-session list --all`, `open FILE --expected-id ID`, and
`status FILE`. `PI_NATIVE_SESSION_HELPER` can select an absolute fixture/host helper;
the default is the packaged `pi-session`. Version-1 JSON rows contain canonical
`file`, native `id`, `cwd`, `title`, `running`, and optional `pending`, `pane`,
`serverPid`, `archived`. The picker never reads SQLite or a host-control socket.
The harness helper optionally reads archive presentation; an unavailable ledger
falls back to native roots. Archive hides picker presentation, not the ability to
open a local native file. No archive/restore mutation is supplied by this picker.

Stable row keys hash the native path; labels include native IDs, so duplicate
titles/checkouts remain distinct. The returned file/ID must match the selection.
Focus guards the captured requesting client PID and the returned server/pane;
there is no implicit alternative client. An actual writer outside this tmux
server is reported instead of starting another writer. Lost helper replies never
cause cancellation or replay. Native kernel locks, not annotations, enforce
host-local writer exclusion. Pending hints are short-lived/reconstructible and
cannot reserve a file after native `/new`, a replaced pane or failed bootstrap.

The host-owned `tmux_project native-window` primitive accepts only bounded JSON
`{cwd, argv}` (2–32 argv elements). It uses the existing project session, literal
argv and an absolute executable, returning `{pane}`. The one-string shell form is
rejected; tmux's trailing-semicolon transport syntax is escaped for data values. It requires no repository/coordinator/account-ready
state. `TMUX_PROJECT_SOCKET` selects a disposable/explicit server when supplied.
The harness helper applies direnv without bypassing trust, and remote wake invokes
that same helper with the frozen native file/ID and a sanitized environment.

The existing real-fzf identity/query retention and removed-selection refusal remain.
Raw rows wait at most 50ms for native discovery; ordinary rows/UI do not wait.
Escape drains discovery, not accepted work; selected opens have their own bounded
context. Real popup fixtures use a local JSON CLI and **no bridge/host socket**.
No stop, delete, repair, generation or schema-negotiation interface is involved.

GRILL/NAS now stage `services.pi-harness.matrixBridge`, preserving their host bot
identities, roots and SOPS files. The service reads the token with `LoadCredential`
as data; neither the native launcher nor tmux receives it. Only socket/root config
reaches the adapter. Ordinary Pi uses the existing centralized engineering profile;
`pi-local-only` is explicit, and workers/headless/experiments do not auto-enroll.
Native and historical managed native-file directories remain discoverable.

The shared server is independently owned and cannot be replaced during a rebuild.
Bridge restart has no tmux/Pi stop hook, PartOf/BindsTo/Requires coupling, or idle
runtime replacement. Running native launchers retain their Nix closures. Explicit
`tmux -N` probes must not start the shared service.

The harness's own tested Pi pin (**0.84.4** in this slice) must not be replaced by
this host's independently updated `nix-ai-tools` input. #172 advanced the published
harness URL/lock and its verified private dependency graph without changing other
root input graphs. For isolated source development, use a Git-aware local override
for evaluation, not a `path:` import of ignored logs:

```sh
python3 modules/cli/pi-harness/check-native-integration.py \
  --harness-source /path/to/pi-harness --evaluate
bash modules/cli/pi-harness/check-shared-session-privileges.sh \
  --harness-source /path/to/pi-harness
```

Historical #164 evidence: 67 top-level Go tests passed with `-race`, zero skips, including real
fzf/tmux, requester-only focus, no-socket discovery, duplicate titles, lost replies
and non-Git native windows. The isolated production picker package built, and its
launcher passed nine helper scenarios against actual patched Pi (direct tmux and
packaged launcher), including `/new`, outside-tmux ownership, partial appends,
slow/failed bootstrap, literal semicolon paths, real direnv and daemon-context
wake with no tmux on inherited PATH. The packaged launcher supplies its own
private tmux/runtime PATH; the bridge need not inherit an interactive shell PATH.
Relative `PI_NATIVE_SESSION_HELPER` overrides are rejected before invocation. GRILL/NAS evaluation reported Pi 0.84.4,
legacy then disabled, native bridge enabled, independent lifetimes and no failed
assertions. These are not Matrix delivery or live cutover receipts. The canonical
cross-repository review/release evidence belongs to harness
`docs/matrix-pi-bridge-evidence.md`. After #170 deletion, **18 retained Go tests**
pass under `-race`, including a removed-command refusal. The isolated picker
package and six consuming source/evaluation checks pass. Removed lifecycle and
pidfd-termination tests disappeared with their obsolete features, not weakened
assertions. Native writer locks remain in Pi; narrow requester/pane/PID/argv
presentation helpers remain here. The legacy Nix options/units/account option
are absent, not disabled alternatives. No published pin or live state changed.

#### Background native rooms and invitations (#165)

Native room setup runs separately from text delivery. Saved room IDs and
immutable create-event provenance win over aliases/display names. Uncertain
creation reuses only the original alias; it never makes a second room. Git errors
or incomplete Space links show setup-pending without blocking local Pi or an
already-bound room. Projects share a Space by Git common directory; linked
worktrees have separate checkout Spaces. Plain workspaces need no Git.

NAS now declares `bridgeChat.assistant.trustedBridgeBots` as an exact host-ID to
bot-MXID map for grill and NAS, replacing `managedAccountHosts`. The existing
owner transport retains the existing credential; the model worker and hosts do
not receive it. This small optional consumer has its own cursor and
`bridge-invites.sqlite` journal, separate from stateless `!pi` requests and from
the historical managed account database. It accepts only first invitations with
matching immutable native-room provenance and exact bot sender/creator. Lost
join acknowledgements are observed, not replayed. Departures stay suppressed;
there is no leave/forget/unban, notification repair or to-device action protocol.
A current room-scoped snapshot precedes join, but Matrix does not offer a
membership CAS against simultaneous actions from another client.

The old account data remains retained in place and in the verified private #172
backup, not read or rewritten by the new transport on startup. Source/evaluation
checks cover this policy on both hosts. Source reconciliation and completed
migration-only activation do not authorize service startup or Matrix membership
effects; legacy pending account jobs are not a new execution queue.

#### Removed managed-window platform (#170)

The managed command catalogue, exact-window ownership/termination, pidfd owner,
coordinator creation, capture/attach protocol and old rollout guard/checker are
removed. `tmux_project managed ...` fails as an unknown command, not a compatibility
mode. The small `tmux_identity.go` presentation validators, literal argv helper,
native picker and fixed-argv native-window launcher remain.

Historical ownership/PTY/focus verification is preserved in Git baseline
`c8d681d64b4a9086a9bbd19aa69f6e410f836e78:specs/tooling.md`, not current operating
instructions. No existing socket, process, history or installed closure was
modified by source removal. The old tmux crash/admission/account incidents remain
unresolved unless independently verified; see the harness historical index.

#### Shared tmux privilege contract (GRILL and NAS)

Native Pi and interactive windows share the same Unix user and tmux server;
they are trusted with that user's authority. The harness native bridge unit sets
`NoNewPrivileges=false`; both hosts import `modules/cli/tmux/shared-server.nix`
for independent server ownership. A bridge-first boot with this flag enabled
would permanently set `NoNewPrivs=1` on a newly started shared server and its
shells, breaking `sudo` (including `shutup`). An operator-first server already
lets bridge-requested windows execute without that restriction, so keeping it on
the bridge is not reliable isolation. Separate untrusted agents
would require a separate identity and tmux server, not this shared socket.
Other Pi chat services retain their own hardening. Sudo authentication and
sudoers permissions are unchanged; this does not grant passwordless access.

Evaluation-only regression check (no build or activation):

```sh
bash modules/cli/pi-harness/check-shared-session-privileges.sh
```

Do not apply the old privilege-only rebuild/reboot recipe to this staged
replacement. It does not quiesce old writers, migrate queues or preserve uncertain
delivery identities. Use the separately approved epic cutover procedure once
available. NoNewPrivs cannot be cleared on existing processes; a configuration
evaluation does not prove their kernel flags changed.

After approved activation, `check-shared-session-privileges.sh --live` reads the
active `pi-matrix-bridge.service`, shared server and invoking shell flags. It never
starts/stops them. This check is not migration permission or proof of delivery.

The host `tmux_project` package owns the runtime for bridge-created tmux windows.
Its private `libexec/tmux` entrypoint supplies plugin interpreters/utilities from
`modules/cli/tmux/tmux-runtime.nix`, preserves the full host launcher, and selects
`${XDG_CONFIG_HOME:-$HOME/.config}/tmux/tmux.conf`. Config hooks and clipboard
commands use absolute host-package paths. Do not solve boot failures by adding
host-specific tmux plugins or dependencies to the generic Pi relay.

After activation, run this isolated boot-environment regression check:

```sh
bash modules/cli/tmux/check-boot-runtime.sh
```

It starts disposable servers with restricted and interactive environments,
checks core options, plugin bindings, command resolution, hooks and reload, then
cleans up only its own sockets. It does not exercise Matrix attachment. A live
server retains its original environment: rebuilding alone does not replace it.
Use the approved maintenance plan for the final bridge-first acceptance test.
Before closing any terminal, check `tmux show-options -gv prefix` (`C-Space`),
`tmux show-options -gv status-position` (`top`), reload with prefix-r, test project
shortcuts and copy/paste, and resume a native Pi file. Inspect
`journalctl --user -u pi-matrix-bridge.service -b` for communication failures.
Successful plugin startup, native focus or attachment is not proof of Matrix
delivery or external tool effects.

Existing windows on historical `/tmp/tmux-$UID/default` sockets remain untouched.
No preview/cleanup command is shipped. Preserve them for separately approved
quiescence and real process-exit observation; a marker or vanished socket cannot
prove process ownership or completion.

### dump.bepis.lol content publishing

GRILL exposes the NAS-backed Hugo project at `~/documents/projects/dump`.
`dump-publish check` validates/renders a temporary site; `dump-publish submit`
submits a completed snapshot and waits for NAS's publication receipt. These
commands publish website content, not NixOS configurations. The existing GRILL
Matrix managed-project bridge can operate this project without an agent on NAS.
See [dump-publishing.md](./dump-publishing.md) for the required first-deployment
transfer order, permissions, limitations and acceptance checks. Do not activate
the GRILL mount over the initial local starter project.

### Mealie recipe agent (GRILL)

The dedicated `~/documents/projects/mealie-agent` project supplies project-local Pi
recipe tools for a separate managed Matrix conversation. Mealie remains on NAS using
`pkgs.unstable.mealie`. See [mealie-agent.md](./mealie-agent.md) for the manual NAS/GRILL
activation order, non-admin account permissions, SOPS token provisioning and live tests.
The agent implementation does not create a room, provision secrets or deploy hosts.

### Tailnet-only ntfy notifications (NAS)

NAS exposes `ntfy.bepis.lol` through the existing tailnet-only HTTPS ingress for
Element X Android UnifiedPush and an authenticated `test` topic. The phone uses
a dedicated non-admin account; no harness/bridge changes or automated alerts are
added. See [ntfy.md](./ntfy.md) for the required SOPS environment file, narrow
Synapse private-address exception, phone setup and deployment acceptance.

### Vikunja task agents (NAS and GRILL)

`todo.bepis.lol` is tailnet-only. NAS has a dedicated managed task workspace/room;
NAS and GRILL use API tokens owned by `beau`; both GRILL profiles share its host's
`vikunja/api-token`. Project bindings currently supply defaults, not enforced access
restrictions. No scheduled agents or confirmation gates are added.

| Command | Purpose |
| --- | --- |
| `vikunja-agent-init <workspace> --project-id <id>` | Opt an existing Pi project into the host's default account and project binding |
| `vikunja-agent-init <workspace> --profile full` | Select the GRILL full profile (currently the same credential and authority) |

See [vikunja-agent.md](./vikunja-agent.md) for SOPS values, account/bootstrap order,
NAS tmux maintenance, room creation, API limitations and offline/live verification.

### Opt-in agent sandbox trial (Grill)

The disabled-by-default `local.agentSandboxTrial.enable` option imports the
locally pinned reusable sandbox module without changing ordinary Pi sessions.
See [agent-sandbox-trial.md](./agent-sandbox-trial.md) for the unpublished revision
strategy, evaluation-only check, explicit provisioning, rollback and separate
activation approval. `nix eval --impure --json --file tests/agent-sandbox-trial.nix`
checks only public/local inputs, not the private fleet configuration.

### Syncthing Git inventory

Read-only inventory of `.git` entries in `~/documents`, `~/monash`, and `~/collab`:

```sh
python3 scripts/inventory-synced-git.py > /tmp/git-inventory-local.json
python3 scripts/inventory-synced-git.py nas grill laptop t480 > /tmp/git-inventory-fleet.json
```

SSH targets need Python 3 and use their login user's home by default;
`--home /home/beau` explicitly selects a home on all targets. No files are installed
remotely. Output includes paths and ref names: keep reports private and outside
synced folders. Inspect `error`, `errors`, and `skipped` fields on every target;
JSON output alone does not mean coverage is complete. Missing hosts remain unresolved.

The script skips mounts, symlinks, the private `sops-secrets` directory, and
`documents/projects/dump`. Git pointer files are reported without following them.
It parses loose/packed refs and HEAD without invoking Git or reading Git config.
Reftable storage is reported as incomplete. It does not inventory reflogs,
unreachable objects, bare repositories, worktree changes, or ancestry; mandatory
separate checks for partial clones, external alternates and LFS are still needed
before satisfying the preparation plan's coverage gate. Equal/different IDs alone cannot prove which
host is ahead. It does not fetch, back up, seed, or alter repositories. Keep `.git`
ignored while gathering inventory; see [syncthing-git-preparation.md](./syncthing-git-preparation.md).

Synthetic regression tests: `python3 -B tests/test-inventory-synced-git.py`.

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

### Tailscale HTTPS proxy (NAS / t480)

See [tailscale-proxy.md](./tailscale-proxy.md) for the always-on client,
NAS TCP/443 ingress, secret provisioning, and deferred deployment acceptance.

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

## Independent native Pi and shared tmux lifetimes (GRILL and NAS)

`nr` generates host imports and runs `nh os switch` with the dotfiles flake,
restoring the original build/activation interface. It does not use a custom
transient activation service, activation lock, or candidate GC root. Direct
`nixos-rebuild` and remote deployment commands retain their own semantics.
Terminal-independent activation is not a guarantee of this wrapper; shared tmux
survives relay replacement because its process ownership is independent.

GRILL and NAS default tmux clients ensure `tmux-shared.service`. The foreground
server owns the existing runtime socket independently of the Pi relay. Its
startup PATH combines current host/user profiles with pinned boot tools: panes
can find ordinary system commands and tmux popup hooks can resolve
`tmux_project`. A server started before this fix retains its old PATH until
explicitly restarted; rebuilding alone will not alter running panes. Custom
`-S`/`-L` sockets remain unmanaged for disposable tests. The server is not
restarted or configuration-reloaded by rebuilds. Its initial system generation
is rooted at `~/.local/state/tmux-shared/runtime`, retaining plugins and hooks.
New Pi processes use the installed launcher; existing Pi processes keep their
retained runtime. Neither idle nor busy Pi is automatically refreshed. Approved
task creators may outlive their caller; failed/uncertain creators retain closure
roots conservatively. A bridge restart has no authority to restart Pi or tmux.

The old managed rollout service/guard is removed. The independent shared server
still refuses to replace a live server at its socket. Unit-file changes cannot
adopt an old process or establish that it exited. Initial cutover must use the
separately approved offline migration runbook, with no overlapping old/new writers.
Do not restart any live service merely to make evaluation match the source.

Disposable shared-PATH verification (not live Matrix or process-exit acceptance):

```sh
bash modules/cli/tmux/check-shared-path.sh
```

A deliberate tmux restart still terminates its sessions. Keep sessions running
on their pinned runtime unless an incompatible/security update requires explicit
maintenance. A failed Matrix connection is not permission to restart Pi.

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
