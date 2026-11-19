# Grill-first DSH trial

Status: the operator reports the previous configuration built and started on
grill, with NAS HTTPS returning an unauthenticated 401 and browser login reaching
the preview notice. Acknowledgement failed because the profile was read-only.
The new Numtide revision has been evaluated, not built or activated here. GPU, Codex and full isolation acceptance
remain pending. This does not replace Pi, tmux or Matrix or change sleep policy.

## Architecture and scope

- `main` supplies `/agent`, the `agent-workspace` group, Syncthing and SecretSpec
  on grill, NAS, t480 and laptop. There is no automatic project migration.
- Only grill enables `services.dshTrial`. It runs Numtide's `dsh` as `dsh-agent`,
  at boot, with restart-on-failure. `nix-ai-tools` pins 0.2.2-rc.4; to upgrade,
  `nix flake update nix-ai-tools` and repeat the smoke test. The separate tools
  nixpkgs input still supplies SecretSpec.
- DSH initializes its own stock `web` profile and owns settings and credentials.
  No seed files or home-level patch mount. Live reload uses the upstream default.
- Nix-owned CLI policy overlays load after the writable settings. They disable
  plugin management, session upload and session telemetry and retain the
  configured permission preset, trusted hostname and cookie lifetime. The sole
  extra plugin, `dsh-native-codex-oauth`, is pinned and packaged by Nix; it runs
  as `dsh-agent` and is trusted with that identity's credentials. This does not make the profile immutable: agent
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

DSH starts in `/var/lib/dsh-agent/home` with `DSH_HOME=/var/lib/dsh-agent/dsh`.
A synced `/agent/.env` is not the server's launch environment. On first use,
rc.4 appends `deepseek-harness/default-workspace` to its configured Documents
directory and canonicalizes that path. A link inside the read-only service root
points that directory to `/agent`; no registry or DSH-specific files are required
in the projects. The base PATH supplies shell utilities, Git, rg, Nix and the
mock SecretSpec wrapper. Enter project environments explicitly, e.g.
`nix develop -c make test`; no automatic `.envrc` activation.

On grill, SSH Git operations can authenticate as Beau using a dedicated GitHub
account key (not Beau’s personal agent socket). The NixOS signer alone gets a
systemd credential sourced from the root-only `dsh/git-ssh-private-key` SOPS
secret. On first agent connection the socket activates the relay and signer;
a fresh signer loads the identity constrained to `git@github.com`. DSH sees
only its socket and GitHub’s pinned public Ed25519 host key. This delegates
account-level Git access to any code running as `dsh-agent`, not GitHub API or
vault access; local commit authorship does not change. Secret rotation restarts
the signer. Revoke obsolete account keys on GitHub, including on rollback.

After activation on grill, run `ssh-add -l` and `ssh -o BatchMode=yes -T git@github.com`
inside a DSH session. Expect one fingerprint and GitHub’s greeting for Beau;
GitHub normally returns status 1 on successful shell authentication. Use
`git ls-remote git@github.com:BeaudanBrown/nix-dotfiles.git HEAD` for a
non-mutating end-to-end transport check. Review changed code, hooks,
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
credential. Private logrotate copies/truncates weekly, retaining four rotations
without restarting the unit. If the original link has aged out, restart at a
convenient time for a new one.
Log in via the browser only after approval. Use DSH's built-in model/provider
OAuth UI for Codex on each host. The pinned `llm-pi-ai` integration advertises
OAuth, but actual Codex account login, refresh and model calls are acceptance
checks, not established by configuration evaluation. In Settings → Models select
`openai-codex` without an API key; look for **Sign in with ChatGPT** on the
provider card. The plugin supplies the web controls; DSH owns the OAuth flow
and credential store. Do not reset private state when adding this plugin.
`modules/services/dsh/codex-oauth.nix` adapts the pinned alpha plugin's Typert
codec descriptors for rc.4; re-test both host registration and browser controls
before upgrading either package.

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

Public checks (no private fleet flake evaluation):

```sh
nix eval --impure --json --file tests/dsh-trial.nix
python3 tests/test_agent_secretspec.py
ruff check modules/cli/secretspec/agent_provider.py tests/test_agent_secretspec.py
ruff format --check modules/cli/secretspec/agent_provider.py tests/test_agent_secretspec.py
pyright modules/cli/secretspec/agent_provider.py tests/test_agent_secretspec.py
# Disposable VM: build and run this BEFORE clearing any state on grill.
nix build --impure --file tests/dsh-smoke.nix --no-link
```

The eval fixture checks fleet wiring. The VM boots the actual Numtide package
under the restricted unit with fresh private state, exchanges its disposable
launch token, checks the HTML response and writable profile, and verifies the
composed upload policy. It uses no OpenAI account and does not simulate NAS or GPU.

### Manual one-time cutover (operator only, on grill)

First pass the VM test above and build the new generation without activating it:
`sudo nixos-rebuild build --flake .#grill`. Stop here if either fails. From the
same checkout, confirm the hostname and paths. This **irreversibly discards all
old DSH settings, sessions, sign-ins and logs with no backup**, as intended.
Never run this cleanup on ordinary restarts or upgrades.

```sh
# On grill only, after both builds have passed:
(test "$(hostname -s)" = grill && sudo systemctl stop dsh-agent.service &&
 sudo -u dsh-agent find /var/lib/dsh-agent -xdev -mindepth 1 -delete) &&
 sudo nixos-rebuild switch --flake .#grill &&
 sudo systemctl start dsh-agent.service &&
 sudo systemctl is-active dsh-agent.service
```

Do not clear `/agent`, `/var/lib/agent-mocks` or any personal home. Read the
new launch link locally with `sudo less /var/lib/dsh-agent/service.log`; never
paste it into reports. Rolling back a generation cannot restore discarded state.

Separate approval is required for builds, host switches, service probes and
account logins. Before unattended use, record all of:

1. Build the unmodified pinned DSH, start with the stock writable profile,
   accept the preview notice in the UI, change an ordinary setting and verify
   both persist after a service restart. Verify complete web/base bundle
   activation, disabled plugin management, no upload telemetry and no approvals.
2. Verify NAS nginx configuration/ACME, tailnet desktop+phone access, off-tailnet
   refusal (including public ingress with this Host/SNI), NAS-to-grill backend
   access and backend refusal from other peers, persistent token login and
   cookie attributes/lifetime after restart.
3. At `https://dsg.bepis.lol` select `openai-codex` and device-code login.
   Have a new session run `pwd` and verify `/agent`. Restart `dsh-agent` and
   make another model request without signing in again. Record refresh after
   access-token expiry separately; persistence across restart isn't refresh.
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

- [DSH CLI parsing and profile composition](https://github.com/deepseek-ai/deepseek-harness/blob/dsh-v0.2.2-rc.4/apps/cli/reference/README.md)
- [DSH profile startup](https://github.com/deepseek-ai/deepseek-harness/blob/dsh-v0.2.2-rc.4/apps/cli/src/profile-boot.ts)
- [DSH connection authentication](https://github.com/deepseek-ai/deepseek-harness/blob/dsh-v0.2.2-rc.4/packages/client/connection/src/index.ts)
- [SecretSpec 0.21.1 dotenv provider](https://github.com/cachix/secretspec/blob/v0.21.1/docs/src/content/docs/providers/dotenv.mdx)
- [SecretSpec 0.21.1 Bitwarden provider](https://github.com/cachix/secretspec/blob/v0.21.1/docs/src/content/docs/providers/bw.mdx)
