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

Managed Matrix project creation uses the host-owned `tmux_project managed
project-create` operation. It accepts only a configured root key, a safe
immediate-child workspace name, a bounded creation key, and an explicit retry
flag. The operation creates no scaffold, task, remote, or publication: it uses a
deterministic private staging directory, initializes local Git on `main`, stores
the creation key in local Git metadata, and atomically publishes the directory.
An exact retry can recover recognized staging phases or a matching completed
repository; symlinks, foreign state, ownership mismatches, and conflicting Git
identity fail unchanged.

Managed Matrix Pi windows use the same per-user tmux server as the interactive
`tmux_project launcher-popup`: managed invocations require `TMUX_TMPDIR` to equal
`XDG_RUNTIME_DIR`. The existing launcher lists ordinary project sessions and
paths plus public-inventory managed conversations. Enter on a managed entry calls
generation-fenced window-first open and switches only the captured requesting
client to the returned exact window/pane; it never sends keys. The host launcher validates and forwards optional
model/thinking selections, derives the canonical workspace path itself, and
stores only bounded conversation ID/concept display options on the window.
Dormant and starting conversations and the coordinator are selectable without
waiting for Pi attachment. Failed startup remains stopped until explicit Enter
retries through the host owner. No stop/refresh/delete bindings are provided.

#### Inventory-backed picker (#118, staged source)

The picker uses only the documented bounded `host-control-v1` inventory/open
protocol, never private registry files. Its native Unix client uses
`PI_MANAGED_SESSIONS_RUNTIME_DIR`, or `$XDG_RUNTIME_DIR/pi-managed-sessions`,
with the same UID/private-directory/socket checks as `pi-managed-session`.
Custom runtime placement must be exported to the picker as well as the CLI.
Missing runtime environment fails closed; there is no CLI fallback or transport
retry. This avoids both an unsupported endpoint-discovery claim and an uncorrelated
second request. Response decoding mirrors the three exact public operation schemas,
including required fields, tagged unions, capability enums, Unicode-code-point length bounds,
case-sensitive keys, and request-ID matching. It rejects partial inventories, repeated
cursors/identities, oversized output and unsupported states. Open is issued once
with the selected generation fence; unknown outcomes are not replayed or cancelled.
Exact focus rechecks the captured client name/PID and the target's birth-bound
window ownership. The existing host lifecycle owns launch joining, retained error
windows and first-window placement.

**Operator-approved outage policy:** managed selection fails closed without the
relay. A tmux marker is not proof that a conversation has not been retired. Ordinary
sessions/raw paths remain available. Ordinary rows target an explicitly unmarked
window, never a mixed session's last managed window. Raw Enter validates the Git
checkout and, if necessary, opens an ordinary shell in a managed-only session.

Rows use immutable conversation IDs. The shared live-v1 checkout digest matches
canonical local paths, not titles, project equality or relative cwd; multiple
same-checkout conversations remain separate while redundant raw paths disappear.
An existing ordinary session remains selectable. Sorting mixes autojump scores
and name/key ties; there is no conversation recency database.

Source-only verification: **58 top-level Go tests passed, zero skips**, including
bounded/malformed inventory, checkout digest compatibility, same-checkout dedup,
outage refusal, exact requester/window selection after renumbering, mixed-session
ordinary selection, and accepted work surviving a lost open response. An integrated
fixture runs the picker through a fake public CLI and selection executable into
real disposable tmux focus. It does not claim real-fzf latency or live relay/Matrix
acceptance; progressive UI and timing evidence belong to #119. External Nix
validation/build and activation were deliberately not run.

#### Progressive picker (#119, staged source)

Start fzf before local/host/path discovery. One combined tmux inventory supplies
sessions, windows and the captured requester; autojump is read once. Independent
roots scan concurrently with fd, without Git per repository. Raw Enter remains the
Git-validation boundary. Host reads and scans are independently bounded.

`$XDG_CACHE_HOME/tmux-project/paths.json` (default `~/.cache`) is disposable path-only
cache data: bounded/schema-checked, basic directory-existence checks, refreshed on
every invocation, private atomic publication with separate concurrent temporaries.
Failed/cancelled scans do not publish partial results. No transcripts, credentials,
conversation recency or lifecycle authority are cached.

Raw rows wait at most a configured **50ms** for managed inventory (headroom inside
the 100ms budget); ordinary live rows/UI never wait for it. Late full reload removes
redundant raw rows. Since fzf's index tracking does not preserve identity across
reordering, a private per-invocation Unix listener and short-lived helper commands
capture the opaque key in fzf's event queue, then restore it on the **result** event.
The query is untouched. A removed selection disables Enter until navigation/query
change, rather than accepting an unrelated replacement. These temporary files are
UI snapshots/receipts only, removed at exit; they are not another session manager.

Escape cancels/drains discovery, not accepted host work. Open runs under its own
bounded context after selection; no stop/delete/cancel/replay is sent. An unavailable
local host-control authority hides managed rows and leaves ordinary navigation
usable. Public `relayState: disconnected` describes **Matrix transport**, not loss
of local retirement/open authority; a reachable local host can still serve safe
inventory and generation-fenced opens while Matrix is disconnected.

Final source checks: **65 top-level tests, zero skips, with `go test -race`**.
Paired Standards/Spec review was followed by strict-schema and transport remediation.
All46 emitted `public-schema-fixture` records also agree with the harness's real
TypeBox parser, checked by `tests/fixtures/managed-picker-schema-check.cjs` in the
harness repository. The checker takes the harness TypeScript-build path and verbose
Go-test log. This caught code-point/UTF-16 length differences rather than trusting
another handwritten fixture. Missing runtime configuration refuses managed reads
without executing a CLI; strict native framing/identity remains the only transport.
Real fzf **0.70.0** / tmux **3.6a** tests exercise an actual keybinding through
`launcher-popup`, a controlling PTY, the public protocol on a private fixture
socket, two late same-checkout conversations, identity/query retention, removed
selection refusal, cache additions/removals and early exit during delayed discovery.
No running relay, Matrix or model is contacted. Deployment must supply a compatible
fzf Unix-listen/result/transform API; external Nix validation remains unauthorized.

Seven cold/warm/error trials distinguish keypress→UI, first selectable row,
managed rows and full discovery. Final medians were **34–36ms UI,
65–67ms first/managed rows**, with full discovery **75–108ms** (cold path-cache
versus warm; OS cache not evicted). Some UI tails exceeded the 50ms target; targets
are not guarantees. A real packaged-CLI baseline took roughly 0.5s for managed
rows due to repeated Node/schema startup; the native client of the same public
protocol removes that overhead without reading private state. Final review and
verification evidence is in harness `docs/managed-picker-evidence.md`; no activation
is implied. Review's request to gate on Matrix `relayState: ready` was rejected with
`HostReadModel.matrixReady()` source evidence and a dedicated regression: local
retirement authority availability is distinct from Matrix transport connectivity.

The #120 GRILL/NAS configuration, exact public device mappings, unresolved package
publication/lock boundary, permitted source checks and staged rollout/rollback are
in [managed-live-workspaces.md](./managed-live-workspaces.md). This is source-only
staging, not a resolved deployment or permission to activate it.

#### Exact managed-window ownership (staged harness integration)

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

Managed and interactive windows share the same Unix user and tmux server; they
are trusted with that user's authority. GRILL and NAS override the upstream relay's
`NoNewPrivileges` to `false` in their respective `modules/cli/pi-harness/<host>.nix`.
Both import `modules/cli/tmux/shared-server.nix` for independent server ownership.
Otherwise a
relay-first boot permanently sets `NoNewPrivs=1` on the shared server and all
its shells, breaking `sudo` (including `shutup`). An operator-first server
already lets relay-requested windows execute without that restriction, so
keeping it on the relay is not reliable isolation. Separate untrusted agents
would require a separate identity and tmux server, not this shared socket.
Other Pi chat services retain their own hardening. Sudo authentication and
sudoers permissions are unchanged; this does not grant passwordless access.

Evaluation-only regression check (no build or activation):

```sh
bash modules/cli/pi-harness/check-shared-session-privileges.sh
```

For an existing affected deployment:

1. Save work in **all** tmux/managed Pi windows. Do not kill the shared server
   while work is running. Restarting the relay alone cannot repair it.
2. Detach from tmux or open a fresh SSH shell without attaching to tmux. Check
   `grep '^NoNewPrivs:' /proc/$$/status` reports `0` and `sudo -v` works.
3. From that clean shell, activate with
   `sudo nixos-rebuild switch --flake /home/beau/documents/nix-dotfiles#grill`.
4. Once all work is saved and a reboot is acceptable, run `sudo reboot` from
   that clean shell. This terminates existing sessions and ensures a fresh
   relay-first server. NoNewPrivs cannot be cleared on a running process.
5. After reboot, attach to tmux and run
   `bash modules/cli/pi-harness/check-shared-session-privileges.sh --live`
   from this repository. It checks the active relay setting and the relay,
   shared server, and invoking shell's kernel flags without changing them.
   Verify `sudo -v`, then coordinator and managed-project attachment. Do not
   use `shutup` as a test unless an actual shutdown is intended.

The live check requires activation and fresh processes; an evaluation pass
alone does not mean the currently running server is fixed.

The host `tmux_project` package owns the runtime for relay-created tmux servers.
Its private `libexec/tmux` entrypoint supplies plugin interpreters/utilities from
`modules/cli/tmux/tmux-runtime.nix`, puts the full host launcher ahead of the
bridge's managed-only wrapper, and explicitly selects
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
Save work and reboot for the final relay-first acceptance test. Before closing
any terminal, check `tmux show-options -gv prefix` (`C-Space`),
`tmux show-options -gv status-position` (`top`), reload with prefix-r, test project
shortcuts and copy/paste, and attach both coordinator and managed project Pi
windows. Inspect `journalctl --user -u pi-managed-session-relay.service -b` for
attachment timeouts. Those timeouts may have a separate cause; fixing plugin
startup is not proof that the bridge attachment lifecycle is fixed.

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
