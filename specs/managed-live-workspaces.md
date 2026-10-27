# Managed live workspaces — pinned GRILL/NAS configuration

**Reconnect-warning follow-up:** current harness `36e286c` includes the production
repair below and limits repeated connection failures to one warning per bound
adapter/outage, while automatic retries continue. A successful reconnect reports
restoration once. All 12 canonical gates passed (625 managed tests, zero skips).
Already-loaded adapters acquire this change only through normal idle refresh or
restart; rebuilding the relay alone cannot replace code in a running Pi process.
No host rebuild, service restart or state mutation was performed by the agent.

**Production compatibility repair (2026-10-27):** the operator's GRILL rebuild
exposed an omitted production state format (`renderingVersion: 2`). Harness
`9c79abe` merges the deployed `c65509a` production fixes into the feature, preserving
frozen projection bytes, durable input receipts and existing session history.
All 12 canonical source gates passed (623 managed tests, zero skips), standalone
packages built, and the final packaged parser read all 34 GRILL conversations
without modifying the registry. See harness `docs/managed-production-upgrade-evidence.md`.
The operator owns the next rebuild; the agent has not evaluated/built hosts,
restarted services, reset state, or migrated conversations.

**Normal-checkout integration:** the operator subsequently requested updating
`~/documents/nix-dotfiles`. The feature changes are integrated into local `master`,
retaining its newer ntfy, workspace roots, host changes and dependency locks.
The only lock node replaced relative to that master is `pi-harness`. This is not
a host evaluation, build, activation or migration. The operator authorized and
completed publication of master at `31d0f67`, including the existing sandbox
commit, before the production compatibility repair.

**Publication/lock update (2026-10-27):** the operator authorized pushing both
feature branches and resolving the reviewed harness pin/lock, but explicitly
excluded host builds. Both `feat/managed-live-workspaces` branches are published;
no default-branch merge, host build/evaluation, activation, production service
restart or migration is part of this step. The prior source-only history follows.

This is the source-only #120 handoff for pi-harness epic #103. It is **not an
activation instruction or evidence of deployment**. No external Nix evaluation,
build, lock resolution, push, service/shared-tmux restart, live Matrix traffic,
secret access, migration or real-client test was authorized or performed at that
handoff. Subsequent #121 authorization permits standalone candidate package
builds and isolated testing, not fleet evaluation/activation or production traffic.
The actual picker expression now built with public harness nixpkgs (66 tests,
zero skips), and its installed wrapper passed private-tmux/fake-host smoke.
See `.loom/workstreams/managed-smoke/handoff.md`; this is not host wiring evidence.

## Resolved package pin (host validation remains outstanding)

`flake.nix` requests the tested harness commit
`36e286cecd8eededfb7299778d03804d014ff045`, including bounded reconnect warnings and deployed production
state/retry compatibility, generation fencing, room-v12 authority,
Matrix-origin/departure recovery and prose approvals; the local picker includes #118/#119 and the
service-locale fix through `6a7b294`. The same `modules/cli/tmux/tmux_project.nix` derivation supplies
both the ordinary picker/keybinding and the managed exact-window launcher.

`nix flake update pi-harness --option builders ''` resolved the published revision
above with `narHash = sha256-p8G9nHbIQxiz9ZmCnL03sOG0rWpkoMwaez/FwB1uLXg=`.
Only the harness node changed from `9c79abe`; all other nodes and follows are
unchanged. The earlier production repair replaced broken `6924263` and normalized
existing nixpkgs node names; graph comparison proved no unrelated source upgrades.
Hash and revision come from Nix resolution, not a manually invented lock entry.

**A resolved lock is not a successful host build or deployment.** The corrected
host rebuild and post-activation health check remain operator-owned. No migration
is authorized by this repair.
The initial publication did not modify default branches; the subsequent local
master integration is described above. Neither step is deployment evidence.

Minimum picker prerequisites: tmux3.6 and the tested fzf0.70 Unix-listen/result/
transform API. The derivation asserts these floors and supplies git, raw tmux,
fzf, fd and Python to its checks. It selects raw tmux for tests, never the fleet
shared-server bootstrap wrapper. Runtime PATH dependencies and the existing
requesting-client keybinding are retained. Direct Go tests are not proof that
this Nix package has been built.

## Public identities (operator supplied from existing-token whoami)

| Role | Host | Exact MXID | Exact device ID |
| --- | --- | --- | --- |
| Dedicated owner login on NAS | recipient for both hosts | @beau:matrix.bepis.lol | PXZRSYBGDY |
| GRILL relay bot | grill | @pi-grill:matrix.bepis.lol | PI_GRILL_RELAY |
| NAS relay bot | nas | @pi-nas:matrix.bepis.lol | LKVMVRCIUY |

These are identifiers, not credentials. Both relays set `accountDeviceId` to the
owner recipient. NAS `bridgeChat.assistant.managedAccountHosts` contains only the
two exact host/bot/device triples; no wildcard trust or display-name inference.
If any login/token is replaced, verify its device mapping again. Existing account
journals bind their owner/recipient identity; changing scope needs explicit
recovery, not editing a live journal or deleting it to bypass a fence.

The NAS account worker reuses the existing `matrixTokenFile` SOPS reference
`pi-chat/matrix-token`. It runs inside the existing deterministic transport,
separate from the model worker. No token is copied to a relay, Pi settings, model
context, Nix store, log or this document. Existing host secrets remain bot-only
`pi/matrix-grill-env` and `pi/matrix-nas-env`. Do not inspect secrets to implement
this handoff. Account automation joins proven rooms, initializes rules only for
new rooms, preserves manual notification changes, and performs authorized exact
leave/forget. Its enablement can have account effects at **future activation**;
setting source configuration is not consent to execute them now.

## Preserved configuration and policy

- GRILL roots: `projects = ~/documents/projects`, `documents = ~/documents`.
  NAS root: `projects = ~/documents/projects`. Host IDs and roots are unchanged;
  these are trusted Git roots, not instructions to enroll existing sessions.
- Exact operator and ignored WhatsApp/Signal/Facebook service MXIDs remain
  unchanged. No unverified owner puppet is granted access.
- `actionPolicyOverrides = { };` preserves the harness's central defaults:
  reads/previews free, every model mutation separately approved, protocol human
  confirmation and coordinator protection retained. No runtime policy or
  notification-setting command is added.
- Normal `pi` and upstream `pi-local-only` explicitly default Pi-R/AgentGraph
  off. Automatic management applies only to eligible interactive launches.
  `pi-local-only` retains engineering resources but strips managed authority.
  `pi-local` still selects the local model through the separate `pi-r-local`
  experimental launcher; its name/resources/evaluation contract are not reused
  for local-only mode. Deliberate experiment packages remain available.
- Runtime retention is explicitly on. Independent `tmux-shared` ownership,
  cgroup/update guard, narrow relay NNP override, scratch/LLM behavior and pinned
  busy runtimes are unchanged. Never restart shared tmux as an update shortcut.
- NAS assistant's existing Note-to-Self allowlist/model, `allJoinedRooms=false`,
  empty remote-owner grants and existing file-service configuration remain
  unchanged. Managed account automation does not widen assistant room/tool grants.
- Host-local registry, account journals, retirement ledger and managed session
  histories are not moved into synchronized ordinary-history storage.

## Staged rollout — separate authorization required

1. Finish cumulative source review (#121). Obtain publication, lock resolution,
   external evaluation/build and deployment permission separately; the present
   approval includes none of those operations. Resolve the package boundary above.
2. Evaluate both GRILL and NAS configurations with the selected input, inspect
   generated policies/units/package paths and version floors, then build targeted
   packages/hosts only as authorized. Confirm model worker isolation and existing
   assistant/file service settings; compare identities without logging tokens.
3. Back up manifests, registry, native managed histories, hierarchy/retirement/
   account state, pending journals and receipts together. Preserve newer
   tombstones and the account preservation baseline. Never restore an active
   manifest without its retirement authority.
4. Stage NAS deterministic account consumer before host account requests. Preserve
   its shared Matrix sync cursor and durable receipts. Existing-room setup must
   preserve notification policy, not reset it. Verify the dedicated owner identity
   and bot-device mappings at this separate live acceptance boundary.
5. Use the existing guarded relay-first rollout on each host. A failed cgroup
   guard leaves the old relay running; do not kill/adopt a foreign server or fake
   ownership. Compatible adapters reconnect while keeping process/runtime IDs.
6. New explicit launches use the new entrypoint. Existing ordinary or busy Pi
   processes are not adopted/restarted. Older loaded adapters keep their runtime;
   refresh only after supported idle consent, never force a busy refresh. Unknown
   capability/version or uncertain identity fails closed.
7. Existing-room hierarchy migration is a distinct operation: read-only
   `pi-managed-session space reconcile preview --json`, inspect exact scope,
   then separately confirm apply with its preview ID. After interruption obtain a
   fresh preview; retained legacy IDs/receipts are not destructive authority.
   Complete admitted legacy #68 scope before separately consenting to checkout
   grouping. No room recreation, inherited-history backfill or implicit reparenting.
8. Separately authorize desktop/Element X/Matrix acceptance: ordinary and managed
   launch/picker behavior, coordinator wake, account joins/rules/manual changes,
   disconnect/reconnect, and exact cleanup. Isolated PTY tests are not this evidence.

Before persistent state changes, withdrawing an unactivated source/package
selection is harmless. After mutation, old strict readers may not accept new
fields; executable rollback is **not** a supported state downgrade. Keep the
compatible relay/runtime and recover from the full backup boundary under a
specific recovery plan. V2 cutover remains separate (#63). Do not delete uncertain
journals, newer tombstones or failed panes to make older code start.

## Permitted source verification

`python3 modules/cli/pi-harness/check-managed-integration.py --harness-source <harness-checkout>`
checks exact public mappings, preserved seams and central policy without importing
Nix or accessing secrets. `nix-instantiate --parse` is syntax parsing only, not
module evaluation; no `nix eval`, `flake check`, lock fetch or build is included.
Direct Go/disposable-tmux tests exercise the owning picker with existing tool
binaries. Generated Nix configuration and real service behavior remain unverified
until separately authorized evaluation and acceptance.
