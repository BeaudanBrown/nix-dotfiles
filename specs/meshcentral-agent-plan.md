# Locally maintained MeshCentral agent: research and implementation plan

Status: **proposal, not implemented or runtime-tested**. Researched 2026-09-12.

## Recommendation and complexity

A reliable, declaratively enrolled **terminal/file-management client is a medium-sized integration**, not just a systemd unit. A proof of concept can be short; the work is packaging, persistent identity, settings reconciliation, update ownership, and regression tests. Full remote desktop is a separate, less predictable effort on this fleet's Wayland compositors.

Recommended direction:

1. A pinned, locally built MeshAgent package using supported Nixpkgs dependencies, subject to a bounded feasibility gate.
2. One small-interface NixOS module, disabled by default, managing a root systemd service and private persistent state.
3. A SOPS-decrypted enrollment file supplied by path, never read during evaluation or fetched from the live server during activation.
4. Nix owns the native executable and compatibility fixes; MeshCentral continues delivering its normal JavaScript core.
5. Pilot terminal/files first; qualify ARM and Wayland separately before fleet enablement.

Rough engineering estimate, **not a commitment**:

| Scope | Estimate / risk |
|---|---|
| Disposable one-host enrollment demonstration | Hours to a day; does not establish production suitability |
| Native-package feasibility and NixOS runtime investigation | 1–2 focused days |
| Maintainable terminal/files module, SOPS lifecycle, tests, x86-64/ARM qualification | Several more days; roughly a working week overall if no substantial upstream fixes are needed |
| Hyprland/Niri desktop qualification and fixes | Additional days, potentially longer; compositor/GPU-dependent |

Expect several hundred lines of local packaging/module/helper code plus tests and small documented upstream patches. Do not turn this into a permanent large MeshAgent fork. If supported crypto or basic NixOS runtime support requires that, stop and reconsider before rollout.

## Scope and evidence

This investigation used public upstream source, the repository's configuration, and static inspection of two public Linux binaries. **No agent was executed, no Nix outputs were built, no system was switched, no live MeshCentral enrollment was attempted, and no private secrets repository was accessed.**

Pinned references:

| Source | Revision |
|---|---|
| This repo's root `nixpkgs` input | `21ea275a7c46aef9d4d6ddc962e6d562e9d94183` (resolved through `nodes.root.inputs.nixpkgs`, not the lock node merely named `nixpkgs`) |
| MeshCentral selected by that package expression | `1.2.0`, commit `386b2f74d0bfaedb6ea15bac5c877cfac93bdb62` |
| MeshCentral upstream inspected | `02eb8f71d2ce48bdbd59e4e4d4844b7edaf0e69d` |
| MeshAgent upstream inspected | `3376e862991bc2efa94225f49c651d8852c90cc4` |
| Public sops-nix input | `bef289e2248991f7afeb95965c82fbcd8ff72598` |

The package expression establishes the configured package version, **not which generation is currently running on NAS**. No live version was checked. Cached public research inputs are under `.pi/tmp/meshcentral-research/`; they are disposable, not an implementation dependency.

### Repository facts

- [`modules/services/meshcentral/nas.nix`](../modules/services/meshcentral/nas.nix) enables the server at `support.bepis.lol`, with TLS offload to localhost, external port 443, WebSockets, and `certUrl`.
- The pinned NixOS module exposes a **server**, not an agent service. Its `settings` are serialized to a Nix-store JSON file; do not put new plaintext server credentials directly in that attrset. [N1]
- Seven ordinary hosts are x86-64: `agent`, `bottom`, `brick`, `grill`, `laptop`, `nas`, `t480`. `pi4` and `oneplus` are aarch64. Hardware declarations, not a guessed CPU model or runtime `uname` mapping, select packages.
- Workstations use Hyprland; the OnePlus configuration includes Niri. The `client` root is not synonymous with MeshCentral agent and is not sufficient to cover every server.
- Current host entrypoints consume **generated explicit imports**. The operative selection is [`inventory/explicit-imports/host-targets.nix`](../inventory/explicit-imports/host-targets.nix) plus its root graph, not just the older recursive-import description in the specs. New files require import regeneration. [`scripts/generate-host-imports.sh`](../scripts/generate-host-imports.sh) includes only Git-tracked module files.
- `research/` is ignored by Git. This durable proposal is therefore in `specs/`, superseding the earlier exploratory research note.

## How the client actually works

### 1. Enrollment is a connection, not an inventory import

The normal installer downloads a platform-specific executable from `/meshagents?id=...` and group configuration from `/meshsettings?id=...`, then invokes `-fullinstall`. The server-generated `.msh` contains `MeshName`, `MeshType=2`, `MeshID`, `ServerID`, and `MeshServer`. For this server the expected control URL is `wss://support.bepis.lol:443/agent.ashx`, but the actual group download must be checked rather than inventing its trust fields. [M1, M2]

The agent establishes an outbound WebSocket/TLS connection and proves possession of its locally generated certificate key. The server derives its NodeID from the certificate public key and creates a node record on first accepted connection. The hostname or `agentName` is a display name, **not a unique identity or admission credential**. [A2, M3]

Consequences:

- One group enrollment file can enroll many hosts; each generates a different identity.
- Reinstalling without the old identity usually creates a new node, even with the same hostname.
- SOPS per-host files provide secret distribution/access control, not a server-enforced hostname allowlist.
- An agent module does not declaratively reconcile MeshCentral users, groups, ACLs, deletions, or exact server-side inventory.
- **Changing `MeshID` on an already enrolled client does not reliably move it.** The inspected server explicitly ignores an existing node's presented group ID and uses its saved server-side group. Move it through the UI/API without discarding identity. [M3]
- Initial `agentName` is used at enrollment; subsequent UI-name synchronization depends on the device group's hostname/name synchronization flags. Merely changing the Nix hostname does not guarantee overwriting a server-side display name. [M3]

A one-time group setup is simplest. Future server inventory reconciliation would be a separate module with centrally held, scoped administrative credentials—not admin tokens distributed to every endpoint. MeshCentral's `meshctrl` supports group creation and agent download; that is not a native NixOS desired-inventory facility. [M7]

### 2. Trust and secrets

`ServerID` pins MeshCentral's **agent-authentication public key**, distinct from the browser-facing HTTPS certificate fingerprint. Agent authentication also checks the web certificate seen on the connection, explaining the existing TLS-offload `certUrl` configuration. Preserve server identity material during server recovery; do not disable validation to solve a proxy problem. [A2, M2]

`MeshID` identifies the enrollment group. In the inspected server, knowing the group identifier can retrieve `.msh` settings unless download locking is configured. Treat the complete enrollment file as sensitive enrollment material, although the server public-key fingerprint itself is not a secret. Invitation expiry/download locking does not revoke an already obtained enrollment file. [M2]

Optional additional server controls include `lockAgentDownload`, `agentAllowedIP`, and a domain `agentKey`. The last requires a manually added `?key=...` in the agent URL and is **not automatically inserted** into `.msh`. It is shared admission gating, not per-host identity. A URL-carried secret can leak into logs; it also needs a proper runtime-secret solution on the server, since the current NixOS server module writes settings into the store. Do not add it as a casual default to this client project. [M5, N1]

For initial deployment, use a dedicated fleet group, restricted group permissions, MFA for operators, securely distributed `.msh`, and explicit review of the server's enrollment exposure. Decide whether stronger admission gating is required before opening fleet enrollment. Enrollment file rotation is not equivalent to revoking a stolen agent identity.

### 3. Identity lives in a private, writable database

The native agent stores `SelfNodeCert` and `SelfNodeTlsCert` in its `.db`; they include private identity material. The database also contains imported settings and the downloaded JavaScript core. It is not disposable cache and must never be shared through Syncthing or baked into an image. [A3]

The default clone-detection logic compares MAC addresses and may reset identity when none of the saved nonzero MACs match. `skipmaccheck=1` disables that behavior. [A4]

Recommended local default: preserve identity by persisted state (`skipmaccheck=1`) so NIC changes/Wi-Fi address changes do not unexpectedly add another client. This deliberately trades away upstream clone detection: templates must exclude the state directory, and restore procedures must prohibit two running machines with the same database. Expose that choice explicitly and test it.

Do not reseed a whole `.db` from SOPS on every start. SOPS supplies enrollment; persistent storage supplies identity. If disk state is lost, recover a same-machine, stopped-service backup or deliberately re-enroll and retire the stale node.

The upstream startup path can also generate new certificates when existing certificate loading fails. A robust adoption/upgrade path must distinguish first initialization from missing/corrupt existing identity and fail before reconnecting rather than silently producing another client. Include an initialized-state guard and corruption tests; a small native guard may be necessary. In particular, test old PKCS#12 identity loading when moving from bundled OpenSSL to a new provider/version—do not treat failed decryption as permission to re-enroll. [A3, A4]

### 4. File placement follows the executable, not just the working directory

On Linux the agent resolves its actual executable using `/proc/self/exe`. It derives `.db`, `.msh`, `.mshx`, `.log`, `.tag`, `.proxy`, and update paths from that location. Changing `WorkingDirectory` or executing a symlink to `/nix/store/.../meshagent` alone does not relocate them. [A1]

The native agent supports foreground `run`/`connect` (or no positional command); `start`/`-d` forks. Use `meshagent run` under a `Type=simple` service, not `-fullinstall`, `start`, or a guessed `--run` flag. No general native-agent `--db`/`--config` interface was found; `--script-db` belongs to JavaScript script mode, not normal agent service startup. [A1]

Preferred layout, **subject to the phase-1 namespace test**:

```text
/nix/store/...-meshagent/
  bin/meshagent                  # real ELF, not a shell wrapper
  lib/meshagent/*.js             # only necessary, pinned compatibility overrides

/var/lib/meshcentral-agent/      # root:root 0700, persistent
  meshagent                     # read-only bind of the packaged real ELF in service namespace
  meshagent.msh                 # atomically rendered, root-only configuration
  meshagent.db                  # unique host identity + settings + runtime core
  meshagent.log                 # bounded by upstream; inspect for sensitive metadata
  ...private bookkeeping / upstream database sidecars...
```

Systemd `BindReadOnlyPaths` can expose a store file at a service-local destination while the containing state directory remains writable. Test that `/proc/<pid>/exe` and the agent's own path resolve to the **state-directory destination**, including self-spawned helper processes. This mechanism has not been tested here. [S1]

It avoids inventing a data-path patch and avoids a mutable copied native executable. If that behavior fails, the documented fallback is an atomic physical copy of the pinned ELF into the state directory before start, verified/replaced on every start. That fallback has weaker between-start executable immutability and needs an explicit design decision—not a silent downgrade. A symlink is not the fallback. Read-only mounts protect against ordinary self-updater writes, not a malicious server already entrusted with root execution.

### 5. `.msh` is an import into a database, not a replacement config

The agent reads `.mshx` before `.msh`. In the normal writable mode it imports settings on startup. Import updates keys that are present, **leaves omitted keys in the database**, and deletes a key when an explicit empty `key=` is supplied. `CoreModule` cannot be overwritten through this settings importer. [A5]

Many switches are tested by presence/nonempty value, not a parsed boolean. Thus `disableUpdate=0` is not a safe way to enable updates, nor is `noUpdateCoreModule=0` a safe way to enable core delivery. Use empty values to clear presence-based switches. Do not set `readonly=1`/`readmsh=1` as a NixOS workaround: state must be writable for initial identity and normal core operation. [A5, A6]

The local module needs a small runtime parser/renderer, not `cp once`:

- Parse bounded line-oriented data, normalize CRLF, validate required keys/expected value forms, and reject duplicate keys, embedded control characters, and unsupported settings.
- Never source/evaluate the file as shell and never print values in failures.
- Initially support the standard five enrollment fields and optional `WebProxy`; extend the allowlist deliberately when an actual requirement arises. Reject configurations requiring unsupported customizations instead of silently dropping them.
- Let the module own `agentName`, `meshServiceName`, `disableUpdate`, `skipmaccheck`, and the explicit clearing of incompatible debug/read-only/core-freeze switches.
- Reject conflicting supplied module-owned settings, rather than depending on duplicate-key precedence.
- Render empty tombstones for every supported optional/module-owned key that should be absent, including `WebProxy=` when removed. Preserve that removal policy across module versions; never wipe the database to apply config changes.
- Fail clearly on an unexpected `.mshx` or legacy override file that would shadow desired settings. Adopt an existing hand-installed agent only through an explicit migration procedure.
- Audit `.proxy`/`.tag` sidecar precedence as part of migration; default to no unmanaged sidecars. If `WebProxy` is managed in the file, use the agent's `ignoreProxyFile` policy to avoid a stale `.proxy` overriding it. [A4]
- Atomically publish a mode-0600 `.msh` only after validation succeeds. Missing or invalid credentials fail service startup; do not reconnect using an old on-disk configuration as fallback.

The database will retain imported enrollment material even if the original SOPS secret resides under `/run`; protect backups accordingly.

### 6. There are two update mechanisms

**Native executable:** the server normally compares hashes and sends a replacement. `disableUpdate=1` makes the agent report a zero hash and refuse native update commands; the inspected server treats a zero hash as “no update needed.” This is important because Nix patching/building changes the executable hash. [A6, M4]

**JavaScript core:** MeshCentral sends its management logic to the agent and caches it as `CoreModule` in the database. This is normal operation. `noUpdateCoreModule` is separate; leave it explicitly cleared so the server can provision/update its core. [A6]

Policy:

- Pin/update the native package in Git and restart it through NixOS deployment.
- Permit ordinary core delivery from the authenticated, trusted MeshCentral server.
- Test each server/package version pair; do not assume indefinite compatibility or that native rollback also rolls back cached core/database state.
- Do not use MeshCentral's manual “agent update”/uninstall actions for Nix-managed clients. The inspected JavaScript `agentUpdate_Start` path does not itself check `disableUpdate`; the native flag alone is not a universal ban on all server-initiated executable replacement. Verify native update suppression and the read-only executable separately. [M6]
- Keep the server secured and updated. This is a privileged remote administration agent: neither SOPS nor binary pinning makes the server unable to run arbitrary root commands on enrolled hosts.

## Packaging findings: why the first proposal needs refinement

### Static inspection of the bundled binaries

Downloaded directly from MeshCentral `1.2.0`'s immutable commit, **not from the live server**, and inspected with `file`, `readelf`, `strings`, and `sha256sum` without execution. [B1, B2]

| Artifact | Bytes | ELF interpreter | Embedded source identifier |
|---|---:|---|---|
| `meshagent_x86-64` | 3,757,520 | `/lib64/ld-linux-x86-64.so.2` | `62b206e0b485b296e8a73a6547cef02bbf5a2d62`; contains a February 2026 date |
| `meshagent_aarch64` | 3,256,688 | `/lib/ld-linux-aarch64.so.1` | `545a176b7dc10bcdd0aba64e7b3a2701e0178af5`; contains 2022 dates |

SHA-256:

```text
x86-64: 891da8d32d0fbfec933b7ca5aa64b27650c05531a772f993601f20ae7c2c0a3b
aarch64: d3e630985cb4b429375d79dd506842da176a9cbe4e0afb992c694cab48f3e7ce
```

Both list only glibc-family direct dependencies (`libpthread`, `libutil`, `libm`, `libdl`, `librt`, `libc`), and both contain **OpenSSL 1.1.1s** version strings, with no `libssl`/`libcrypto` dynamic dependency. That is evidence of bundled crypto, not proof of a particular exploitable CVE. OpenSSL 1.1.1 public upstream support ended in September 2023; do not assume these artifacts have downstream security backports. Installing a newer `pkgs.openssl` beside them does not replace statically incorporated OpenSSL. [O1]

The source revisions indicated by the binaries were also inspected: they have the same relevant settings-import, identity-MAC-check, executable-path, and native-update mechanisms described above. That does **not** mean they contain current upstream desktop/security fixes.

### Recommended package strategy

Prefer a local source derivation under `packages/meshagent/`, pinned to a reviewed MeshAgent commit and fixed source hash. The current inspected revision is a **candidate**, not an approved production version.

The upstream makefile offers `DYNAMICTLS=1` to avoid bundled static TLS, and `NOTURBOJPEG=1` to link the system JPEG library. Adapt include/library paths to Nixpkgs rather than accepting `/usr/include/openssl` or checked-in static archives. Verify compilation and runtime with the selected supported OpenSSL; the existence of the switch is not proof that current OpenSSL works without fixes. Audit other bundled dependencies too; Duktape/zlib still make MeshAgent upstream security maintenance relevant. [A7]

Build natively for `x86_64-linux` and `aarch64-linux` initially. Upstream currently has CI examples for both. Architecture ID 6 is x86-64; current ARM source CI uses 26, while the server also recognizes 32 for ARM64. Confirm the built binary reports the intended identity/capabilities and selects the matching server core, rather than confusing the download endpoint ID with a hostname or device ID. [A7, M8]

Keep package concerns out of fleet policy:

- Correct native loader/RPATH and explicit runtime dependencies. Avoid enabling global `nix-ld` as the production solution; it addresses only part of the problem.
- Reproducible source provenance/commit metadata even when `.git` is absent; the makefile otherwise tries to derive it from Git.
- No build-time dependency on the live support server, device group, or enrollment secrets.
- No interpreter wrapper that makes helper re-execution point at a shell script instead of the real agent ELF.
- Runtime `PATH` for the agent's shell probes: coreutils, awk/grep/sed, process tools, util-linux, systemd/loginctl, and user lookup utilities as actually needed.
- Direct and dynamically discovered library dependencies tested independently: `readelf` does not enumerate `dlopen` requirements.

Two concrete NixOS compatibility defects deserve targeted treatment:

1. `monitor-info.getLibInfo` probes `whereis ldconfig`, parses `ldconfig -p`, then falls back to `/lib`. Nix library paths/RPATH alone do not make that discovery logic correct. [A8]
2. `service-manager` searches `/lib/systemd/system` and `/usr/lib/systemd/system`, while NixOS declares units under `/etc/systemd/system`; it also parses human-formatted `systemctl status`. Patch the necessary read/query paths to use correct unit discovery and machine-readable `systemctl show`, without giving upstream install/uninstall ownership. [A9]

Prefer small package-owned JS overrides for those seams, with explicit Nix library paths, rather than global fake `/usr/lib`, global linker caches, or an FHS container that hides the host being administered. The loader checks local JS files before embedded JS/database modules (after native/object handlers); test override loading both during bootstrap and after MeshCore arrives. Read-only-bind the required overrides into the agent's lookup location alongside the ELF. [A10]

**Editing `modules/*.js` and running `make` is not sufficient evidence that a patch shipped.** The C runtime contains compressed embedded JS copies. Either use and test the explicit file-override mechanism or deterministically regenerate the appropriate embedded payloads. Do not maintain two unverified versions of a fix. [A10]

Fallback assessment: a fixed-hash, `autoPatchelf`-adapted upstream binary is useful to isolate packaging/runtime faults or to run an explicitly accepted short-lived pilot. Given the observed bundled crypto and architecture age mismatch, it is **not the recommended unattended fleet default**. If native packaging needs a large crypto port, return with options rather than enabling insecure packages or silently shipping the old binaries.

## Proposed module interface and SOPS integration

Proposed options, **not existing options in this repo or nixpkgs**:

| Option under `services.meshcentral-agent` | Purpose |
|---|---|
| `enable` | Defaults false |
| `package` | Defaults to local pinned native package; allows a deliberately tested override |
| `settingsFile` | Nullable absolute runtime path to private enrollment text; defaults null, required when enabled; reject `/nix/store` paths |
| `agentName` | Defaults to `config.networking.hostName`; validate a bounded safe hostname-style string |
| `skipMacCheck` | Defaults true for persisted-state identity; documents cloning trade-off |

Do not initially expose arbitrary `extraSettings`, multiple instances, automatic database reset, custom installer commands, or a universal sandbox-strength knob. Add desktop-specific package/device options only when the concrete implementation is qualified.

Illustrative fleet-policy configuration (the module still needs implementation):

```nix
# modules/services/meshcentral-agent/network.nix
{ config, lib, ... }:
{
  imports = [ ./module.nix ];

  config = lib.mkIf config.services.meshcentral-agent.enable {
    services.meshcentral-agent.settingsFile =
      config.sops.secrets."meshcentral/agent-msh".path;

    sops.secrets."meshcentral/agent-msh" = {
      sopsFile = lib.custom.sopsFileForModule __curPos.file;
      mode = "0400";
      restartUnits = [ "meshagent.service" ];
    };
  };
}
```

A separate pilot host override would set:

```nix
services.meshcentral-agent.enable = true;
```

The generic `module.nix` defines options/runtime behavior and knows nothing about SOPS, hostSpec, roots, or fleet recipients. The `network.nix` policy connects the runtime-path interface to SOPS using the existing [`specs/secrets.md`](./secrets.md) convention. It is explicitly imported; its non-root filename is intentional.

For one common fleet group, use a multiline `meshcentral/agent-msh` value in the network-root secret file. If distinct per-host/group enrollment files are wanted, replace the shared secret-policy block with declarations in corresponding host/root modules using `sopsFileForModule __curPos.file`, setting `settingsFile` there. Do not layer an unused shared network secret requirement underneath per-host enrollment, and do not cross from one feature module into another root's secret file. A per-host SOPS key does not mean MeshCentral enforces a per-host enrollment token.

The **user**, not the agent, would obtain the group `.msh`, edit the appropriate private file, and update recipient encryption when necessary. For a shared network-root file the user command is:

```bash
ssh nas 'cd /home/beau/sops-secrets && sops secrets/network.yaml'
```

Use `just gen-sops-yaml` / `just update-sops` when recipients or host keys change, per the secrets spec. Publish the encrypted change and update the public repo's secrets input through the normal workflow before deployment. No decrypted content should appear in commits, Nix evaluation, build logs, command-line arguments, or downloadable Nix artifacts.

### Systemd lifecycle

- Service name `meshagent.service`, matching explicitly rendered `meshServiceName=meshagent`.
- Root identity: remote system administration requires broad privileges. Use `StateDirectory=meshcentral-agent`, mode 0700, and `UMask=0077`.
- `LoadCredential` snapshots `settingsFile` into a service-private credential path; the runtime renderer consumes it, validates it, and atomically writes the effective `.msh`. This is path-based secret injection, not Nix `builtins.readFile`. The SOPS `restartUnits` entry is essential because changing plaintext behind an unchanged path does not change the Nix derivation. [S1, S2]
- Order after actual SOPS installation. sops-nix can use activation scripts **or** `sops-install-secrets.service`; add a required dependency only when that unit is enabled, not unconditionally. Test both modes. [S2]
- Start at boot, use foreground `run`, restart with bounded backoff, and handle shutdown cleanly. `network-online.target` is ordering, not proof the remote server is reachable; agent reconnect behavior must handle outages without boot-time enrollment downloads.
- Bind only the packaged ELF/needed JS overrides read-only; leave state writable. Ensure the selected package remains in the NixOS closure and package changes restart the constant-path service (`restartTriggers` if needed).
- Do not blindly add `ProtectHome`, `PrivateDevices`, `PrivateUsers`, a read-only host filesystem, or restrictive capability/syscall filters: they can defeat host file management, terminal sessions, or KVM. Even mount namespace effects need testing for remote mount/rebuild operations; keep SSH as a break-glass path. Disable core dumps by default and keep agent debug ports off. Validate hardening against intended operations, not a generic systemd score.
- No inbound firewall opening for baseline server-relayed control/terminal/files. Qualify optional WebRTC/P2P separately; do not advertise unrestricted direct-connection functionality as tested.

## Desktop support: a distinct qualification track

Upstream merged Wayland/multimonitor PR #351 on **2026-09-04**, shortly before this research, after months of public testing. It uses DRM/EGL capture and libevdev/uinput input, not a promise that any compositor's desktop portal makes the agent work. The author's listed tests cover KWin/Mutter and several GPUs. A follow-up examination of the discussion found an **August 22 report of successful use on multiple NixOS machines running Hyprland**. This is direct tester evidence, but gives no detailed packaging, GPU, or acceptance-test matrix; it raises confidence without qualifying this fleet. No Niri success report was established. The older README still recommends disabling Wayland for some display managers. [W1, A7]

This corrects the initial research's incomplete impression of Hyprland evidence. Given the fleet already has SSH, prioritize a bounded Hyprland desktop pilot alongside package feasibility: establish the additional value before investing in the full client module. A successful pilot should include reconnects, lock/unlock, clipboard, scaling/multiple displays, and suspend/resume—not only an initial picture.

The old bundled binaries inspected above predate this implementation. Fresh source is not equivalent to a tested release; importing it also imports recent changes requiring review.

Desktop qualification must cover:

- Dynamic lookup of libX11/Xtst/Xext/Xfixes/Xrandr/xkbfile for X11 and libdrm, EGL/GLES, libwayland-client, libxkbcommon, libevdev for newer Wayland paths, plus matching graphics drivers.
- Actual access to DRM devices and `/dev/uinput`, session discovery, socket/Xauthority access, and helper re-execution.
- Hyprland on the real workstation GPUs; Niri on OnePlus; ARM desktop only after headless ARM success.
- Login/lock screens, logged-out state, multiple monitors, scaling, keyboard layout, suspend/resume, and whether user-consent policy behaves as intended.

Do not change the fleet to X11, disable lock screens, or expose devices broadly as an implicit workaround. Terminal/files remain useful independently. Do not label Wayland supported until hardware acceptance passes.

## Implementation work packages and acceptance gates

### Phase 0 — Confirm the operator contract

Agree on initial scope: terminal/files on `agent` as a low-risk x86 pilot, then an ARM host; desktop separately. Confirm the live server version, intended group/permissions, admission exposure, and recovery access with the user. No production secrets are needed for synthetic tests.

**Exit:** explicit hosts, expected features, trust model, and rollback owner.

### Phase 1 — Bounded package/runtime feasibility

With separate authorization for builds, package a pinned candidate with supported TLS/JPEG dependencies. Use an isolated NixOS test VM and synthetic `.msh`/server identity, not live fleet credentials. Test native startup, read-only-bind executable path, library discovery, unit detection, native helper re-execution, and shutdown. Establish the minimal Nix compatibility overrides.

**Exit:** real native ELF on NixOS, maintained crypto confirmed, writable persistent state without store writes, and no uncontrolled installer/self-update dependence. If not achievable with small patches, stop and report alternatives.

### Phase 2 — Implement the deep module

Keep four responsibilities local and separate:

- `packages/meshagent/`: source/hash pin, dependency adaptation, limited runtime overrides.
- `modules/services/meshcentral-agent/module.nix`: generic options and systemd contract.
- A small module-local runtime settings renderer: strict input validation, explicit clearing, atomic private output.
- `modules/services/meshcentral-agent/network.nix` and pilot host override: fleet/SOPS policy.

Add tests through the public module interface plus focused renderer tests. Keep the generic module disabled by default. No server ACL reconciler or general fleet framework.

**Exit:** deterministic preparation, missing-secret failure, identity preservation, settings removal, and update ownership are covered by automated tests.

### Phase 3 — Synthetic integration tests, then pilot

Proposed tests (to implement/run after build authorization):

| Test | Required observation |
|---|---|
| Module disabled | No running service, enrollment-secret requirement, or client firewall opening |
| Missing/malformed/duplicate/unsupported settings | Startup fails clearly; no values in logs; no connection using stale `.msh` |
| LF/CRLF and settings changes | Correct normalized config; removed optional keys cleared without deleting identity |
| Unexpected `.mshx`/`.proxy`/legacy installation | Clear conflict/migration behavior, not accidental precedence |
| First enrollment | Exactly one new node in the intended synthetic group; valid nonempty persistent identity |
| Restart/reboot/Nix generation change | Same NodeID; native executable/overrides match selected package |
| Missing/corrupt previously initialized identity | Fail before re-enrollment; preserve evidence/backup; no automatic new certificate on upgrade |
| SOPS rotation | Service restarts, consumes new credential snapshot; unchanged secret does not cause pointless restart |
| MAC/NIC change | Behavior matches `skipMacCheck`; cloned images have no inherited identity |
| Native update attempt | Automatic update suppressed; immutable executable preserved; connection/core still operational |
| Core update | Server can supply/replace core while native executable remains Nix-controlled |
| Group/name change | Documented server-authoritative group and name-sync behavior; no identity reset workaround |
| Server/DNS/proxy outage | Service survives/retries and reconnects; boot/deployment do not fetch enrollment |
| TLS/proxy fault | Wrong server identity is rejected; current TLS-offload configuration works without bypasses |
| Terminal/files | Correct host filesystem/users/PATH/PTY behavior; upload/download; no unintended sandbox isolation |
| Suspend/reconnect | Laptop/phone reconnect without duplicate identity |
| x86-64 and aarch64 | Correct native architecture, core selection, dependencies, runtime lifecycle |
| Upgrade/rollback | Reconnection, preserved identity, documented core/DB compatibility limits |
| Logging/backup | No private identity/credential values exposed; state backup is treated as sensitive |

Once synthetic checks pass, the user activates the pilot using the normal deployment workflow. Verify in MeshCentral and keep independent SSH available. A process being `active` is not proof the node has authenticated or remote access works.

### Phase 4 — Fleet policy and generated imports

Stage/track new module files before using the import generator, with normal approval for repository changes. Regenerate selected host imports via the existing generator/`just gen-imports <host>` workflow; do not hand-edit generated files. Evaluation-only checks can confirm options/unit wiring before authorized builds.

After x86 and ARM pilots pass, enable the shared policy with per-host opt-outs. The `network` selection covers all nine ordinary fleet targets including `bottom`. `grill` and `t480` select `gaming`, but omit `resolveGraph`, so the generator's default `true` expands them to `minimal, common, network, client, main, work, gaming`. Local evaluation and their existing generated imports confirmed this. Explicitly test that the newly generated agent policy is included for **both grill and t480**, not just the pilot. Leave `iso` and `installer` excluded and verify both, since they have different entrypoints. Coordinate encrypted recipients and desired secret files; do not make missing-secret machines unexpectedly fail at boot through a blanket enable.

For later additions: add the host/roots/recipients normally, give it the enrollment file, regenerate imports, and deploy. It appears on first successful agent connection—no per-host web installation.

### Phase 5 — Maintenance and retirement runbook

- Record a tested server/native-package matrix and test both architectures on native package changes.
- On updates, review upstream/security changes, update fixed pins, verify linked crypto, rerun settings/identity/update tests, canary, then roll out.
- Back up state only in a consistent stopped-service/snapshot workflow; never distribute one host's identity to another active host. Preserve the entire private state directory/sidecars, not just guessed certificate files.
- Retain state on disable/uninstall/rollback by default. Disabling stops the service; it does not necessarily remove plaintext state or delete the server's node record.
- Retirement is explicit: disable/deploy, verify disconnected, delete/revoke the server record as appropriate, and deliberately erase private local state/backups according to retention policy. Deleting only the UI node while an agent still has valid enrollment can let it reappear; deletion is not automatically revocation.
- Avoid automatic restore of old DB backups during rollback: a rollback of the executable is not a transaction rollback of server-delivered code or state. Provide a tested recovery procedure instead.

## Corrections to the earlier sketch

- This is idiomatic local integration, **not canonical upstream NixOS support**. The upstream NixOS issue was closed as stale/not planned; that is evidence of no delivered solution, not proof the client cannot work. [N2]
- Global `nix-ld` is neither established as sufficient nor preferred for a maintained package.
- Generic heavy “systemd hardening” conflicts with the purpose of a full-host remote admin agent.
- Copying `.msh` once is not declarative configuration reconciliation.
- Persistent identity has a MAC-based reset rule unless deliberately disabled.
- Native executable pinning does not pin all remotely executed JavaScript.
- Changing enrollment group/name does not necessarily reconcile existing server records.
- Wayland support now exists in very recent upstream source, but not in the inspected bundled binaries, and fleet compatibility is unproven.

## Validation performed

- Markdown LSP: no diagnostics.
- Document whitespace, code-fence balance, local links, and all 26 source-reference labels: passed.
- Both illustrative Nix snippets: syntax parsing passed; this does not establish that the proposed options exist or evaluate.
- Pure local inventory evaluation: all nine ordinary targets include `network`; `iso` does not. Existing generated imports independently confirm inheritance for grill/t480.
- No native package build, agent execution, live enrollment, secret decryption, or desktop test was performed.

## Standards

Independent plan review: **no findings**.

## Spec

Independent plan review raised **one medium/current-issue finding**, alleging grill/t480 had `resolveGraph=false` and would miss network policy. That factual premise was rejected after checking the file, the generator's `or true` default, pure inventory evaluation, and both existing generated imports. The rollout section now spells out that inheritance and explicitly requires grill/t480 coverage tests. No extra gaming-root secret policy is necessary for the current import graph.

## Primary sources

Source claims above are tied to these revisions; runtime/packaging proposals remain explicitly untested.

- [N1] Pinned Nixpkgs [MeshCentral package](https://github.com/NixOS/nixpkgs/blob/21ea275a7c46aef9d4d6ddc962e6d562e9d94183/pkgs/by-name/me/meshcentral/package.nix) and [NixOS server module](https://github.com/NixOS/nixpkgs/blob/21ea275a7c46aef9d4d6ddc962e6d562e9d94183/nixos/modules/services/admin/meshcentral.nix).
- [N2] Upstream [NixOS agent issue #5802](https://github.com/Ylianst/MeshCentral/issues/5802) (status-only evidence, not an implementation guide).
- [M1] Official [Linux installer](https://github.com/Ylianst/MeshCentral/blob/02eb8f71d2ce48bdbd59e4e4d4844b7edaf0e69d/agents/meshinstall-linux.sh#L147-L190).
- [M2] Server [`.msh` generation/download controls](https://github.com/Ylianst/MeshCentral/blob/02eb8f71d2ce48bdbd59e4e4d4844b7edaf0e69d/webserver.js#L6797-L6870).
- [M3] MeshCentral 1.2.0 [agent authentication and identity](https://github.com/Ylianst/MeshCentral/blob/386b2f74d0bfaedb6ea15bac5c877cfac93bdb62/meshagent.js#L500-L552) and [existing group authority/name synchronization/new nodes](https://github.com/Ylianst/MeshCentral/blob/386b2f74d0bfaedb6ea15bac5c877cfac93bdb62/meshagent.js#L743-L891).
- [M4] Server [binary hash comparison](https://github.com/Ylianst/MeshCentral/blob/02eb8f71d2ce48bdbd59e4e4d4844b7edaf0e69d/meshagent.js#L2141-L2165).
- [M5] MeshCentral 1.2.0 [configuration schema](https://github.com/Ylianst/MeshCentral/blob/386b2f74d0bfaedb6ea15bac5c877cfac93bdb62/meshcentral-config-schema.json) (`agentKey`, `lockAgentDownload`, `agentAllowedIP`).
- [M6] MeshCentral 1.2.0 [JavaScript manual agent update implementation](https://github.com/Ylianst/MeshCentral/blob/386b2f74d0bfaedb6ea15bac5c877cfac93bdb62/agents/meshcore.js#L6607-L6680).
- [M7] Official [meshctrl source](https://github.com/Ylianst/MeshCentral/blob/02eb8f71d2ce48bdbd59e4e4d4844b7edaf0e69d/meshctrl.js) (`AddDeviceGroup`, `AgentDownload`, `GenerateInviteLink`).
- [M8] MeshCentral 1.2.0 [agent architecture table](https://github.com/Ylianst/MeshCentral/blob/386b2f74d0bfaedb6ea15bac5c877cfac93bdb62/meshcentral.js#L3216-L3258).
- [A1] Agent [executable path discovery](https://github.com/Ylianst/MeshAgent/blob/3376e862991bc2efa94225f49c651d8852c90cc4/meshcore/agentcore.c#L6263-L6310), [default database/settings locations](https://github.com/Ylianst/MeshAgent/blob/3376e862991bc2efa94225f49c651d8852c90cc4/meshcore/agentcore.c#L4966-L5033), [foreground/daemon behavior](https://github.com/Ylianst/MeshAgent/blob/3376e862991bc2efa94225f49c651d8852c90cc4/meshcore/agentcore.c#L5506-L5560), and [script-mode database argument](https://github.com/Ylianst/MeshAgent/blob/3376e862991bc2efa94225f49c651d8852c90cc4/meshcore/agentcore.c#L5978-L6021).
- [A2] Agent [server/agent challenge-response verification](https://github.com/Ylianst/MeshAgent/blob/3376e862991bc2efa94225f49c651d8852c90cc4/meshcore/agentcore.c#L2993-L3148) and [MSH documentation](https://github.com/Ylianst/MeshAgent/blob/3376e862991bc2efa94225f49c651d8852c90cc4/readme.md#L24-L65).
- [A3] Agent [certificate serialization/loading](https://github.com/Ylianst/MeshAgent/blob/3376e862991bc2efa94225f49c651d8852c90cc4/meshcore/agentcore.c#L2228-L2469).
- [A4] Agent [MAC identity reset and sidecar imports](https://github.com/Ylianst/MeshAgent/blob/3376e862991bc2efa94225f49c651d8852c90cc4/meshcore/agentcore.c#L5287-L5374).
- [A5] Agent [settings importer](https://github.com/Ylianst/MeshAgent/blob/3376e862991bc2efa94225f49c651d8852c90cc4/meshcore/agentcore.c#L4565-L4635) and [startup precedence/cache flags](https://github.com/Ylianst/MeshAgent/blob/3376e862991bc2efa94225f49c651d8852c90cc4/meshcore/agentcore.c#L4966-L5033).
- [A6] Agent [native update handling](https://github.com/Ylianst/MeshAgent/blob/3376e862991bc2efa94225f49c651d8852c90cc4/meshcore/agentcore.c#L3453-L3583), [presence-based update configuration](https://github.com/Ylianst/MeshAgent/blob/3376e862991bc2efa94225f49c651d8852c90cc4/meshcore/agentcore.c#L4435-L4448), and [cached/core-update behavior](https://github.com/Ylianst/MeshAgent/blob/3376e862991bc2efa94225f49c651d8852c90cc4/meshcore/agentcore.c#L5552-L5644).
- [A7] Agent [makefile](https://github.com/Ylianst/MeshAgent/blob/3376e862991bc2efa94225f49c651d8852c90cc4/makefile#L561-L654) and [x86/ARM CI](https://github.com/Ylianst/MeshAgent/blob/3376e862991bc2efa94225f49c651d8852c90cc4/.github/workflows/linux-build.yml).
- [A8] Agent [library discovery](https://github.com/Ylianst/MeshAgent/blob/3376e862991bc2efa94225f49c651d8852c90cc4/modules/monitor-info.js#L37-L80).
- [A9] Agent [systemd service discovery/querying](https://github.com/Ylianst/MeshAgent/blob/3376e862991bc2efa94225f49c651d8852c90cc4/modules/service-manager.js#L1809-L1914).
- [A10] Agent [JS lookup precedence](https://github.com/Ylianst/MeshAgent/blob/3376e862991bc2efa94225f49c651d8852c90cc4/microscript/ILibDuktapeModSearch.c#L243-L346) and [embedded compressed modules](https://github.com/Ylianst/MeshAgent/blob/3376e862991bc2efa94225f49c651d8852c90cc4/microscript/ILibDuktape_Polyfills.c#L2510-L2529).
- [B1] Inspected [x86-64 binary](https://github.com/Ylianst/MeshCentral/blob/386b2f74d0bfaedb6ea15bac5c877cfac93bdb62/agents/meshagent_x86-64) and [embedded-revision source](https://github.com/Ylianst/MeshAgent/blob/62b206e0b485b296e8a73a6547cef02bbf5a2d62/meshcore/agentcore.c).
- [B2] Inspected [aarch64 binary](https://github.com/Ylianst/MeshCentral/blob/386b2f74d0bfaedb6ea15bac5c877cfac93bdb62/agents/meshagent_aarch64) and [embedded-revision source](https://github.com/Ylianst/MeshAgent/blob/545a176b7dc10bcdd0aba64e7b3a2701e0178af5/meshcore/agentcore.c).
- [O1] OpenSSL project [1.1.1 end-of-life announcement](https://openssl-library.org/post/2023-09-11-eol-111/).
- [W1] Upstream [Wayland/multimonitor PR #351](https://github.com/Ylianst/MeshAgent/pull/351), merged 2026-09-04, the [August 22 Hyprland-on-NixOS tester report](https://github.com/Ylianst/MeshAgent/pull/351#issuecomment-5380394134), and [DRM/libevdev session handling](https://github.com/Ylianst/MeshAgent/blob/3376e862991bc2efa94225f49c651d8852c90cc4/meshcore/KVM/Linux/linux_kvm_wayland.c).
- [S1] Official [systemd.exec manual](https://www.freedesktop.org/software/systemd/man/latest/systemd.exec.html) (`StateDirectory`, `BindReadOnlyPaths`, `LoadCredential`).
- [S2] Pinned public sops-nix [restart options](https://github.com/Mic92/sops-nix/blob/bef289e2248991f7afeb95965c82fbcd8ff72598/modules/sops/default.nix#L150-L169), [activation-mode option](https://github.com/Mic92/sops-nix/blob/bef289e2248991f7afeb95965c82fbcd8ff72598/modules/sops/default.nix#L319-L335), and [unit/activation implementations](https://github.com/Mic92/sops-nix/blob/bef289e2248991f7afeb95965c82fbcd8ff72598/modules/sops/default.nix#L466-L514).
