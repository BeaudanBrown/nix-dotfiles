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

**Not rebuild-ready.** Harness epic #160 / ADR 0003 supersedes the managed
platform. Source changes, isolated package builds and NixOS evaluation are not
activation or migration permission. Quiescing old writers/consumers and the final
migration/release checks remain required. The old runtime/protocol stays only
until the controlled removal slice; it is not the ordinary launch path.

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
this host's independently updated `nix-ai-tools` input. The published harness URL/
lock has **not** yet advanced to this unpublished replacement. Until release, use
a Git-aware local override for evaluation, not a `path:` import of ignored logs:

```sh
python3 modules/cli/pi-harness/check-native-integration.py \
  --harness-source /path/to/pi-harness --evaluate
bash modules/cli/pi-harness/check-shared-session-privileges.sh \
  --harness-source /path/to/pi-harness
```

Evidence: 67 top-level Go tests passed with `-race`, zero skips, including real
fzf/tmux, requester-only focus, no-socket discovery, duplicate titles, lost replies
and non-Git native windows. The isolated production picker package built, and its
launcher passed nine helper scenarios against actual patched Pi (direct tmux and
packaged launcher), including `/new`, outside-tmux ownership, partial appends,
slow/failed bootstrap, literal semicolon paths, real direnv and daemon-context
wake with no tmux on inherited PATH. The packaged launcher supplies its own
private tmux/runtime PATH; the bridge need not inherit an interactive shell PATH.
Relative `PI_NATIVE_SESSION_HELPER` overrides are rejected before invocation. GRILL/NAS evaluation reported Pi 0.84.4,
legacy disabled, native bridge enabled, independent lifetimes and no failed
assertions. These are not Matrix delivery or live cutover receipts. The canonical
cross-repository review/release evidence belongs to harness
`docs/matrix-pi-bridge-evidence.md`; rooms/media/workspaces/archive/migration remain
separate epic slices.

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

The old account data is retained for the later approved offline migration, not
read or rewritten on startup. Source/evaluation checks cover this policy on both
hosts. This is still an unpublished, undeployed replacement; it is not permission
to activate either host or mutate Matrix membership.

#### Historical exact managed-window ownership (retired from ordinary launch)

The following managed protocol notes describe the legacy implementation retained
until epic #160's controlled removal, not the new picker/launch API. Earlier
managed rollout instructions are not a replacement cutover procedure.

Forced stopping uses Linux pidfds on amd64/arm64, never a numeric-PID signal or
window-container kill. Unsupported kernels, denied syscalls, missing process
birth proof and other platforms fail closed. Kernel support is checked before
exact creation. There is no extra daemon or dependency; the existing launcher
continues to own this protocol.

The read-only `root-resolve` returns canonical project session placement without
creating a shell window. Exact project creation can therefore use the existing
first-window placement behavior. `root-ensure` remains an explicit ensure action.

The additive operations `coordinator-ensure-exact`, `window-create-exact`, `window-inspect-exact`,
`window-check-exact`, and `window-terminate-exact` retain ownership in this launcher. Legacy operations and
existing running windows are not automatically upgraded or adopted. Legacy
`window-terminate` and `legacy-window-cleanup` now refuse mutation; neither can
bypass exact process identity through a window-container kill.

Coordinator exact ensure accepts conversation and launch identities only, uses
fixed host environment and the original persisted coordinator session, and
returns the same birth-bound ownership in the protected `default` session. It
never adopts an existing or retained dead pane and never switches a client.

An exact project create takes the normal conversation/placement request plus a fresh
`launch_<32 hex>` identity. Its `ownership` result binds the conversation, server
PID/start time/private random server token, launch ID, session/window/pane IDs,
original pane PID, `processBootId` and `processStartTicks` (Linux boot UUID and
kernel process start ticks). The creation process is pinned while its birth is
captured and verified again after marker installation. A birth token in the command supplied to tmux at creation
prevents later marker installation from adopting a replacement window. The
server-side marker guard also checks that the original pane is still the only
pane in the window. Reserved `@managed_pi_server_id`, `@managed_pi_launch_id`,
`@managed_pi_pane_id`, `@managed_pi_pane_pid`, `@managed_pi_process_boot`, and
`@managed_pi_process_start` options are private runtime
ownership, not user configuration; do not restore them into another server.

Exact inspect returns `{conversationId, exists, ownership?}`. Malformed,
legacy, changed-PID respawned, multi-pane, linked, or ambiguous observations fail
closed; connection failure is not an absence claim. Older proofs without birth
fields remain readable but never authorize forced stopping. Birth fields must
be present together and are not silently added to old records.

The additive read-only `window-observe-exact` accepts `{proofs:[...]}` with 1–64
unique conversation proofs. It returns `{observations:[{conversationId,launchId,state}]}`
in request order, where state is `running`, `stopped`, or `unknown`. One tmux
inventory is shared across the batch, with original process/birth checks per proof.
An exactly matching retained dead pane is stopped; changed ownership remains
unknown unless the original process is independently proven gone. Legacy proofs
without birth identity remain unknown. Malformed/partial responses are not usable.
This is last-known presentation evidence only: it never authorizes termination,
adoption, replacement or window cleanup. Existing exact-check/terminate behavior
is unchanged. It creates no daemon and does not send terminating signals.

Termination opens a pidfd first, verifies the recorded birth identity and live
handle, checks the frozen terminal ownership, then revalidates the pinned
process. TERM and, after a bounded two-second grace, KILL are sent through that
same handle. A replacement or additional pane after the ownership observation
cannot redirect the signal or be destroyed by a container kill. No process
handle survives the launcher invocation. The former format-only mutation
prototype has been removed, including from tests.
The read-only exact check distinguishes `match`, `gone`, and `changed`. A missing
original window on the same server or a different server lifetime can be `gone`;
changed markers/processes/panes/session links are not absence. If the server
cannot be contacted, the result remains unknown unless read-only process
existence observation proves the original server PID no longer exists. PIDs are
bounded to positive signed 32-bit values before that observation. This sends no
process signal. `gone` additionally requires positive absence of the original
process, or a different verified birth identity for its reused PID. Window
closure alone cannot hide a surviving/orphaned process; uncertainty remains an
error and never authorizes a PID kill. Callers must check after a termination
acknowledgement, which acknowledges signalling, not completed cleanup. Retained
dead panes or windows containing replacement work are never forcibly removed;
window cleanup stays pending until their disappearance can be established. This is window ownership, not proof that Pi is currently
attached or idle.

Acceptance/crash evidence: Go tests use disposable private tmux sockets to cover
server restart with reused numeric IDs, changed markers/process/session,
respawned panes, added unrelated panes, foreign birth tokens, legacy refusal,
last-window acknowledgement, dead-handle rejection, birth mismatch, TERM-to-KILL
escalation, replacement during observation, and panes added after observation.
The real dispatch test creates and stops a dummy process using the public API. The entire
launcher suite passes with `go test -count=1 ./...` from
`modules/cli/tmux/tmux-project-go`. No Nix build, host evaluation, activation or
live-session migration is implied. Harness integration belongs to epic #103
retirement/launch work; rollout must install the compatible launcher before
using these new operations.

#### Exact requesting-client focus (#116/#118 integration)

`tmux_project managed window-focus-exact` accepts the public open result's
`conversationId`, `launchId`, `sessionName`, `windowId`, `paneId`, plus an explicit
`clientName` and decimal-string `clientPid`, as a strict JSON object on stdin.
Capture both client fields before admitting a launch. Like other managed primitives it
requires `TMUX` to be unset and `TMUX_TMPDIR` to equal `XDG_RUNTIME_DIR`; the caller
must capture its requesting client before clearing inherited tmux targeting.
It refuses an absent/ambiguous client, missing kernel ownership or changed
launch/window/pane. A final tmux-server-side guard covers replacement and client
disconnection between observation and switching. The guard checks the captured
PID with the client-loop format; `switch-client -c` itself requires the client
name, not a numeric PID. It returns `{ "focused": true }` only after switching.
No implicit client, launch, readiness wait, replacement, session/window cleanup or
mutation replay is supplied. A disconnected caller does not grant retry authority.

| Acceptance/crash boundary | Evidence |
| --- | --- |
| Stable window/pane after index renumbering | Disposable-server/control-client test |
| Switch only the explicitly requested client | Two disposable clients in different sessions |
| Target changes after inspection | Inject changed launch marker immediately before server-side guard; no switch |
| Missing/detached client, changed PID or stale launch/window | Refusal without fallback to another client, including disconnect after observation |
| Managed selection preserves ordinary sessions | No automatic default-session cleanup on managed-window selection; stable-ID candidate targets |

Direct Go verification with tmux **3.6a** passed **43 top-level tests, zero skips**,
including eight focus/dispatch/no-cleanup cases and the existing kernel ownership
suite. Tests use disposable sockets and real control-mode clients. LSP could not
establish an active build for this cross-repository folder; direct Go compilation
and tests provide that evidence. Native tmux shared-session semantics remain:
clients deliberately attached to the same session share its selected window;
this does not introduce per-client session groups or a session manager.

This is a targeting primitive and legacy live-row safety improvement, not the
completed inventory-backed conversation picker or automatic Pi wrapper. Ordinary
navigation discovery, cancellation/performance and full frontend integration
remain owned by the epic handoffs. No Nix evaluation/build, activation, shared
server restart or live Matrix acceptance is implied.

#### Requester capture and outside-tmux attachment (#116)

The operator authorized source changes and disposable Go/tmux tests in the
managed-live-workspaces worktree, retaining all no-Nix-build/evaluation/deployment/
push restrictions. UI-only operations support default launch:

- `managed ui-capabilities` accepts only `{}` and reports version 1 with
  `clientCapture`, `exactFocus`, and `exactAttach`. It requires Linux and tmux
  3.6+ by read-only `tmux -V`; it neither contacts nor creates a server. Default
  launch negotiates this before host admission rather than discovering an
  unsupported focus/attach interface after creating resources.

- `managed client-capture` accepts `{paneId, sourceServerPid, clientName?}`. Capture
  the original server PID and pane from the invocation before clearing `TMUX`.
  It rejects client inventories over 64 KiB, requires exactly one matching
  original server/pane/client, and returns `{clientName, clientPid}` for subsequent
  exact focus. Multiple viewers of the same pane require an explicit client name;
  it never chooses the most recent client. A foreign server with reused pane IDs,
  detached client, malformed or oversized inventory is refused. No server is
  started, marked or modified by capture.
- `managed window-attach-exact` accepts the five exact target fields used by focus
  (no client fields). This is a Linux terminal UI operation, not a JSON success
  receipt. After exact ownership inspection it rechecks the same target guard in
  the server queue before attaching a new client to that exact window/pane. It
  occupies the caller's terminal until detach; it never creates a window, replaces
  a process or cleans up a session. A stale guard returns an actual error, rather
  than treating `display-message`'s zero status as success. Caller stdout must be
  a terminal. The real terminal device is passed to tmux, not the `/dev/tty` alias;
  the UI goes directly to that terminal while command output is bounded to 64 KiB.

These retain unset `TMUX` and matching `TMUX_TMPDIR`/`XDG_RUNTIME_DIR` requirements.
Capture happens before host admission; loss of the caller after admission never
cancels or replays the host operation. Attach/focus failure leaves the existing
owned process intact for explicit recovery. Native shared-session selection
semantics remain unchanged.

Acceptance evidence: **48 top-level Go tests passed, zero skips** with tmux 3.6a.
New cases cover ambiguous shared-pane clients, explicit client selection, foreign
server identity, detached requester, malformed/oversized capture, bounded attach
output and nonterminal refusal without changing a redirected file. Linux PTY
subprocess tests exercise the actual strict dispatcher, terminal attach and
explicit detach, plus marker replacement between inspection and queued attach
with nonzero refusal and no surviving client. Existing exact-focus/process tests
pass after sharing the target-guard implementation. Initial PTY tests exposed
and corrected tmux's rejection of the `/dev/tty` alias. LSP has no active build
for this external folder; direct Go compilation/tests are the evidence.

Full default-launch and picker integration still belongs to the harness/epic;
these primitives alone do not complete #116 or #118. No Nix evaluation/build,
activation, shared tmux restart or live Matrix traffic was performed.

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

For the one-time transition from deployments that used `/tmp/tmux-$UID/default`,
`tmux_project managed legacy-window-preview` accepts `{}` and reports only valid
marked windows. `tmux_project managed legacy-window-cleanup` still parses exactly
`{"confirmed":true}` but refuses mutation even with the relay stopped: a marker
cannot prove which current processes belong to the original window. Preserve
these windows pending ownership-safe inspection; this command no longer performs
migration cleanup. No automatic restart or adoption is implied.

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

## Restart-safe managed-session updates (GRILL and NAS)

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
New Pi processes use the installed launcher. With the harness runtime-update
support deployed, the relay compares managed project adapters' launcher identities
and automatically refreshes changed instances only after the adapter confirms it
is idle and settled. Busy or unknown instances defer; dormant conversations are
not started for an update. Ordinary unmanaged Pi instances and the coordinator
are not automatically refreshed. `!status` reports pending project updates.

The harness's `pi-managed-session-rollout.service` checks the server PID and
cgroup before submitting a single relay restart. Legacy ownership blocks rollout
without killing sessions. For the first migration, finish work and explicitly
close the old tmux server in an approved maintenance window, then run:

```sh
systemctl --user start tmux-shared.service
systemctl --user restart pi-managed-session-rollout.service
pi-managed-session-status
```

Do not bypass a failed guard by restarting the relay directly. The independent
server cannot adopt an existing relay-owned PID merely by changing unit files.

New managed project sessions start directly with Pi as their first window;
existing project sessions keep all their windows and receive a new Pi window.
The coordinator's `default` session follows its separate existing policy.

Disposable lifecycle verification (never operates on the live socket or relay):

```sh
bash modules/cli/tmux/check-update-lifecycle.sh ../projects/pi-harness/scripts/relay-rollout.sh
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
