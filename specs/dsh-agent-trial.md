# Grill-first DSH trial

Status: the operator reports the previous configuration built and started on
grill, with NAS HTTPS returning an unauthenticated 401 and browser login reaching
the preview notice. Acknowledgement failed because the profile was read-only.
The writable-settings revision below is evaluated and locally tested, but has
**not yet been built or activated**. GPU, Codex and full isolation acceptance
remain pending. This does not replace Pi, tmux or Matrix or change sleep policy.

## Architecture and scope

- `main` supplies `/agent`, the `agent-workspace` group, Syncthing and SecretSpec
  on grill, NAS, t480 and laptop. There is no automatic project migration.
- Only grill enables `services.dshTrial`. It runs upstream DSH 0.2.2-rc.1 as
  `dsh-agent`, at boot, with restart-on-failure. A separate nixpkgs input pins
  DSH and SecretSpec 0.21.1 without updating the fleet/Pi pins.
- DSH now uses the unmodified pinned nixpkgs package; the local source patch is
  removed. Its web/base profile is seeded once into writable host-local state.
  DSH saves preview acknowledgement and ordinary settings in `cordis.patch.yml`;
  it also rewrites `cordis.yml` during startup. Both operations must be allowed.
- Nix-owned CLI policy overlays load after the writable settings. They disable
  plugin management, HMR, session upload and session telemetry and retain the
  configured permission preset, trusted hostname and cookie lifetime. No
  community plugins are added. This does not make the profile immutable: agent
  commands can modify it or execute other downloaded code. The installed package
  stays pinned in the store; OS restrictions remain the security boundary.
- This is a shared, autonomous single-user development identity. All `/agent`
  projects can read/change each other. Approvals are `never`; the only configured
  permission preset is `danger-full-access`. These settings are not a sandbox.
- systemd `RootDirectory` supplies a narrow filesystem view without a VM or
  container runtime. Writable binds: `/agent`, `/var/lib/dsh-agent`, and
  `/var/lib/agent-mocks`. Read-only mounts include the public Nix store, resolver
  files, the Nix daemon socket and GPU runtime paths. No personal homes, host
  NFS mounts, Docker/SSH/display/input sockets or private SOPS paths are mounted.
- No sudo, wheel, Docker group, capabilities, privileged namespaces or trusted
  Nix identity. Nix builds must use sandboxing without fallback, static `nixbld`
  identities, and a non-trusting daemon configuration. Store paths are not a
  secret boundary: never put credentials in derivations or public store files.
- An IPv4/IPv6 nftables output guard blocks RPC/NFS ports 111, 2049 and 20048
  for the agent **and the nixbld group**, because fixed-output derivations can
  use the network under build identities. This affects all local Nix builds on
  grill, not just DSH requests. Normal-user/kernel-mounted NFS is unchanged.
  The guard persists if DSH stops and is reapplied atomically on restart.
  Unusual NFS ports, remote builders, relays and future firewall changes require
  renewed review; do not claim arbitrary hostile-service isolation.
- AMD `/dev/kfd` and renderD128/renderD129 are optional device binds; no card,
  input or desktop sockets are passed. GPU functionality is not yet exercised.
- Limits: MemoryHigh 85%, MemoryMax 90%, TasksMax 4096, CPU/IO weight 50.
  No hard CPU quota. Nix daemon/build work and VRAM are outside these limits.
  Verify grill's real workload/headroom before activation; t480 is not evidence.
- Networking otherwise remains open. The existing PostgreSQL `trust` policy and
  thought-capture service access are explicitly accepted unchanged. Do not add
  real project credentials to compensate for APIs that mocks cannot emulate.

## Shared projects and state

`/agent` is owned by the configured Syncthing user (normally the primary user)
and group `agent-workspace`, mode 2770, with default ACLs. Both Syncthing units
explicitly declare this supplementary group so activation refreshes process
credentials when adding the workspace; existing `PrivateUsers` hardening remains. Syncthing ignores
permissions: local tmpfiles rules establish the root ACL. Files *moved* into the
workspace may retain old modes/ACLs; the operator must normalize those files
before expecting group collaboration. Restrictive application-created modes may
also need repair. We deliberately do not recursively chmod arbitrary projects.

Syncthing includes Git metadata, uncommitted/untracked source, conflict files,
lockfiles, databases and build outputs by default. Exclusions are limited to
`node_modules`, `.venv`, Python bytecode and named Python tool caches. There is
no blanket `.gitignore`, `.env`, `*.db`, `*.lock`, `data/` or `build/` exclusion.
**Do not put secrets or live database storage in `/agent`.** Use host-local
state paths instead. User handles conflicts, host wake/sleep and handoff; there
is no writer lock or coordination system.

Harness state, sessions, model authentication, browser-token/cookie state and
private service logs live under `/var/lib/dsh-agent` (0700), outside Syncthing.
They are intentionally accessible to commands running as the same agent user.
No backup or state-migration rollback guarantee is supplied for this trial.

The seeder creates missing profile files with mode 0600 and does not overwrite
existing settings, even on restart or a Nix upgrade. It publishes complete files
without replacing concurrent edits. Moving from the old read-only profile repairs
ownership of its former mountpoint directories via tmpfiles, then seeds the empty
profile after the old service mount namespace is gone. Sessions and credentials
are not moved or deleted, and the preview notice is not pre-accepted.

A Nix rollback does not roll back mutable settings. Resetting a profile is an
explicit operator action: stop DSH, move its `dsh/profiles/web` directory aside,
then restart to seed a fresh profile. This resets profile settings but leaves
other state intact. Do not reset/delete the entire harness state directory.

Normal-user Git/SSH/GitHub/vault credentials are not supplied. The operator
handles private clones, fetches, pushes and GitHub actions; agents can make
local commits and clone public repositories. Review changed code, hooks,
`.envrc`, Nix expressions and manifests **before** running them as the normal
user with real credentials.

## Browser access and model login

The endpoint is `https://dsg.bepis.lol/`, available **only over the tailnet**:

```text
Tailnet browser -> NAS HTTPS ingress -> grill tailnet IP:3080 -> DSH
```

NAS registers a normal `hostedServices` entry with `tailnet = true` and
`webSockets = true`. This reuses existing NAS DNS, nginx ingress and ACME with
`cloudflare/env`; it does not publish this service through Cloudflare DDNS.
Shared hosting ACME defaults use `1.1.1.1:53` for certificate challenge checks,
avoiding NAS's private authoritative zones. This applies to all certificates
inheriting those defaults, not a DSH-specific exception. This changes only
certificate validation, not client DNS or ingress exposure.
NAS DNS points the name at NAS, not grill. The existing ingress machinery
restricts the virtual host to the tailnet listener (or the private backend when
TLS passthrough is enabled for other services). There is **no new secret**, ACME
configuration or HTTPS listener on grill. No private file was read or modified.

The proxy preserves Host/WebSockets, marks cookies Secure/HttpOnly/SameSite=Strict,
and disables per-vhost request/error logs because URLs contain bearer tokens.
Startup/configuration errors still reach systemd. Grill binds DSH to its concrete
tailnet IPv4 address, not a wildcard. Its separate nftables input guard drops
backend traffic unless it arrives on tailscale0 from NAS's configured tailnet
IPv4 address. This guard applies even though tailscale0 is otherwise trusted;
DSH requires the guard service before startup. Existing restart-on-failure
behavior retries if the tailnet address is not yet assigned.

Both NAS and grill need explicitly approved activation. NAS remains the HTTPS
proxy only; DSH itself is still enabled only on grill. The NAS proxy must be
available to use the harness through this domain.

Token-link login remains enabled. Connection cookie lifetime is **400 days**;
browser policy may shorten it. Initial login URLs are in the private
`/var/lib/dsh-agent/service.log`, not the shared journal. Treat this file as a
credential. It currently has no rotation; monitor growth during the trial.
Log in via the browser only after approval. Use DSH's built-in model/provider
OAuth UI for Codex on each host. The pinned `llm-pi-ai` integration advertises
OAuth, but actual Codex account login, refresh and model calls are acceptance
checks, not established by configuration evaluation. No LiteLLM or community
OAuth plugin was added. If upstream login fails, stop and report it.

## One SecretSpec workflow, two stores

Projects declare standard `secretspec.toml`, with a unique safe `[project].name`:

```toml
[project]
name = "demo"
revision = "1.0"

[profiles.default]
DATABASE_URL = { description = "Development database URL" }
```

Both users run `secretspec run -- <command>` from the project. Colleagues may
use ordinary `.env` workflows instead. Avoid hardcoding real-provider chains
or real secret values into shared project manifests.

- Normal user: the login environment defaults to the `bw` Password Manager
  provider at `https://pw.bepis.lol` (existing Vaultwarden, **not** `bws`).
  Configure `bw config server`, login and unlock explicitly as that user;
  SecretSpec 0.21.1 can use an unlocked CLI/BW_SESSION. Never put a session in
  `/agent`, agent environment or a shell history command literal. Provider
  credential references introduced after this pin are not claimed here.
  Vaultwarden compatibility still needs an authorized live trial.
- Agent: a generic packaged `secretspec` wrapper locates the nearest project
  manifest under `/agent` and selects
  `dotenv:/var/lib/agent-mocks/<project.name>.env`. This external directory is
  shared locally with the normal user and contains **mock values only**. No
  per-project launcher, NixOS rebuild or secret synchronization is needed.
  All profiles of a project currently use this one mock file; use a different
  project identity if different mock stores are required.
  Explicit manifest/provider overrides are rejected by the wrapper. The raw
  CLI is still reachable in the store: provider names/wrappers are convenience,
  not authorization. Filesystem and credential absence provide the boundary.

Populate mocks manually outside the repository; the wrapper does not silently
create missing values or translate production secrets into mocks. Provider
settings and manifests can be changed by project code, which is why **actual
vault credentials must remain absent** from the agent environment/filesystem.

## Registry remediation

NAS's existing localhost Distribution backend now authenticates using the same
htpasswd as nginx, delivered with systemd `LoadCredential` rather than making
the SOPS file world-readable. Existing frontend clients retain their usernames,
passwords and HTTPS endpoint; Authorization is forwarded normally.

**Deployment prerequisite:** every htpasswd entry must already be bcrypt, or
must be migrated by the operator before activation. A pre-start check refuses
empty/non-bcrypt files without printing usernames/hashes. Neither the private
file nor existing passwords were inspected. Fresh authenticated pulls/pushes,
registry UI and Moonlight, plus unauthenticated loopback refusal, must be tested
before considering the remediation operational.

## Evidence and acceptance gate

Evaluation-only checks (public locked inputs, no private fleet flake evaluation):

```sh
nix eval --impure --json --file tests/dsh-trial.nix
python3 tests/test_agent_secretspec.py
python3 tests/test_dsh_profile_state.py
ruff check modules/cli/secretspec/agent_provider.py tests/test_agent_secretspec.py
ruff format --check modules/cli/secretspec/agent_provider.py tests/test_agent_secretspec.py
pyright modules/cli/secretspec/agent_provider.py tests/test_agent_secretspec.py
ruff check modules/services/dsh/seed-profile.py tests/test_dsh_profile_state.py
pyright modules/services/dsh/seed-profile.py tests/test_dsh_profile_state.py
```

The writable-settings revision passes five routing tests, four profile-state
tests, evaluation assertions, Ruff and Pyright (zero errors/warnings).
The profile-state tests cover writable private copies, atomic settings replacement
surviving restart, an empty former mountpoint and preservation of a partial profile.
These are local filesystem tests, not proof of successful browser acknowledgement.
`git diff --check` also passed. Tools were
already available locally; no package build was performed.

They check module assertions, disabled hosts, unit/derivation evaluation,
resource controls, identity, mount declarations, sync policy and mock routing.
They do not prove systemd mounts/device access, external authentication or
network enforcement. Generated imports were refreshed with the repository's
selection algorithm, substituting the public locked nixpkgs input and including
the new modules explicitly; no private flake input was opened.

Separate approval is required for builds, host switches, service probes and
account logins. Before unattended use, record all of:

1. Build the unmodified pinned DSH, start with the writable seeded profile,
   accept the preview notice in the UI, change an ordinary setting and verify
   both persist after a service restart. Verify complete web/base bundle
   activation, disabled plugin management, no upload telemetry and no approvals.
2. Verify NAS nginx configuration/ACME, tailnet desktop+phone access, off-tailnet
   refusal (including public ingress with this Host/SNI), NAS-to-grill backend
   access and backend refusal from other peers, persistent token login and
   cookie attributes/lifetime after restart.
3. Complete per-host Codex OAuth, refresh and a real model/tool round trip.
4. Test filesystem/socket denial, inability to edit Nix-owned policy or gain privileges,
   Nix daemon operation and sandboxing; test NFS refusal both directly and from
   a fixed-output derivation. Verify no unintended alternate NFS ports/relays.
5. Test AMD compute, resource headroom, stop/restart behavior and log growth.
6. Test Syncthing create/edit/delete/conflict behavior and local ACLs on all
   four main hosts, including moved projects and restrictive creator modes.
7. Exercise ordinary user Vaultwarden resolution and agent mock-only resolution
   with synthetic projects; then validate all registry clients and refusal.

Architecture impact: adds a distinct shared development identity, filesystem
view, package pin, network policy, secret-provider routing and host-local web
service; strengthens existing registry authentication. No Overalls ADR changes
are applicable to this separate dotfiles repository. Outstanding operational
checks above remain deployment gates, not assertions of implemented isolation.

### Pinned API references

- [DSH CLI parsing and profile composition](https://github.com/deepseek-ai/deepseek-harness/blob/dsh-v0.2.2-rc.1/apps/cli/reference/README.md)
- [DSH profile startup](https://github.com/deepseek-ai/deepseek-harness/blob/dsh-v0.2.2-rc.1/apps/cli/src/profile-boot.ts)
- [DSH connection authentication](https://github.com/deepseek-ai/deepseek-harness/blob/dsh-v0.2.2-rc.1/packages/client/connection/src/index.ts)
- [SecretSpec 0.21.1 dotenv provider](https://github.com/cachix/secretspec/blob/v0.21.1/docs/src/content/docs/providers/dotenv.mdx)
- [SecretSpec 0.21.1 Bitwarden provider](https://github.com/cachix/secretspec/blob/v0.21.1/docs/src/content/docs/providers/bw.mdx)
