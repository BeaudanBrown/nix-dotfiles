# Vikunja hosting and agent integration — agreed direction

Implementation and operator provisioning: [vikunja-agent.md](./vikunja-agent.md).
The implementation was requested with **no evaluation or rebuild**. The research
below records initial findings; the version-specific API contract and limitations
in the implementation guide supersede broad assumptions here.

## Requested direction

- Vikunja hosted on NAS; primary conversational agent also on NAS.
- Dedicated persistent NAS Matrix room as the initial primary interface.
- HTTPS at `todo.bepis.lol`, accessible only through the tailnet.
- Updated decision: use the single Vikunja account `beau`. NAS and GRILL each consume
  `vikunja/api-token`; both GRILL profiles share the GRILL credential. Project-level
  restrictions should be tool policy, not separate accounts. That enforcement remains
  unimplemented: current project bindings only supply defaults, and both GRILL
  profiles have identical authority.
- Low-level tools operate on user instruction, including deletion and bulk changes,
  without additional confirmation prompts, preview/confirm protocols or slash-command
  gates. This does not authorize unsolicited changes or automatic permission escalation.
- No scheduled agents, proactive messages, webhook automation or autonomous execution.
- Support software-project issue tracking and everyday life projects, including sub-projects.
- Potential replacement for GitHub epic workflows is a later phase, not an initial migration.
- This document records the agreed direction and proposed implementation, not build
  or deployment approval.

## Repository findings

- `modules/hosted-services/server.nix` owns HTTPS/ACME and DNS declarations. Its
  `tailnet` default is false: explicitly decide exposure before implementation.
- `modules/hosted-services/nas.nix` supplies tailnet split DNS.
- The root flake inputs resolve to `nixpkgs_3` (stable) and `nixpkgsUnstable`;
  do not mistake the transitive `nixpkgs` lock node for the root stable input.
  Their package sources currently select Vikunja **2.4.0** and **2.6.0** respectively.
- The root stable NixOS Vikunja module supports package selection, loopback address,
  port, environment files, SQLite/PostgreSQL/MySQL, and persistent state under
  `/var/lib/vikunja`. It does not provision an nginx virtual host or automatically
  provision PostgreSQL merely by selecting that database type.
- `modules/cli/pi-harness/grill.nix` enables the existing GRILL managed relay.
  NAS instead enables the separately isolated chat assistant in
  `modules/services/matrix/nas.nix`; these are different integration paths.
- `specs/mealie-agent.md`, `modules/services/mealie/grill.nix`, and the local
  `~/documents/projects/mealie-agent/.pi/extensions/mealie.ts` demonstrate
  project-owned typed tools, runtime token-file configuration, and a dedicated room.
- The local pi-harness README describes project extension support in managed
  sessions. These sessions have host-user authority, not application isolation.
  Actual implementation must verify the consuming pinned harness contract.

## Official functionality and fit

Current official documentation is a capability guide, not a substitute for testing
against the selected release; the public demo can run development code.

| Capability | Proposed use | Official source |
| --- | --- | --- |
| Arbitrarily nested projects | Separate Software and Life trees with smaller workstreams | [Projects](https://vikunja.io/help/projects/) |
| Parent/subtask and blocking/blocked-by relations, including across projects | Epic-like task decomposition and dependencies | [Relations](https://vikunja.io/help/task-relations/) |
| List, Kanban, Table, Gantt | Everyday capture, workflow boards, and dated planning | [Features](https://vikunja.io/features/) |
| Saved filters, date math, timezone-aware filtering | Today, overdue, waiting, and cross-project review views | [Filters](https://vikunja.io/docs/filters/) |
| Recurrence and absolute/relative reminders | Bills, maintenance, appointments and routines | [Dates/reminders](https://vikunja.io/help/dates-and-reminders/) |
| Descriptions, comments, mentions, attachments | Task context, decisions, supporting documents | [Tasks](https://vikunja.io/help/tasks/) |
| User/team/link sharing with read/write/admin permissions | Separate agent identities and accessible project sets | [Sharing](https://vikunja.io/help/sharing-and-teams/) |
| Scoped API tokens; API v2 PATCH and conditional requests | Typed multi-agent clients with conflict detection | [API v2](https://vikunja.io/docs/api-v2/) |
| Project events and user reminder webhooks | Potential future Matrix reminders and change notifications | [Webhooks](https://vikunja.io/help/webhooks/), [developer docs](https://vikunja.io/docs/webhooks/) |
| CalDAV | Optional task-client interoperability; documented early-alpha limitations | [CalDAV](https://vikunja.io/help/caldav/) |

### Important qualifications

- Nested projects group work; parent tasks represent decomposable outcomes. Do not
  create a project for every task or assume the two hierarchies are equivalent.
- Blocking relations are not proven enforcement or agent claim/lease semantics.
- Tokens have action scopes; do not assume a token can be restricted to project
  IDs independently of its owning account. The chosen single-account setup therefore
  permits server-side access to all of beau's accessible projects; any future tool
  restriction will not prevent direct API access by the trusted host user.
- API v2 has conditional reads and generated PATCH operations, but inspected 2.6.0
  handlers do not establish atomic conditional writes. Projects have no ETag;
  AutoPatch does GET then PUT. The client uses best-effort stale-read detection,
  not a transactional lock. See the implementation guide.
- Do not assume recurrence creates a fresh task ID: determine lifecycle behavior
  before attaching automated completion logic to repeating tasks.
- Saved filters are documented as personal, not necessarily shared dashboards.
- Webhook failures are documented as not retried. Durable notifications need a
  receiver/queue and reconciliation; webhooks alone are not a reliable work queue.
- The editor supports Markdown input, but the stored API description format must
  be verified rather than assuming GitHub Markdown round trips unchanged.
- No verified GitHub-equivalent PR linkage, code review, or epic execution engine.
  Replacing GitHub workflows requires separate harness integration and acceptance.
- CalDAV should not be the initial integration dependency.

The official [release list](https://github.com/go-vikunja/vikunja/releases) and
[security advisories](https://github.com/go-vikunja/vikunja/security/advisories)
identify security fixes in 2.6.0. Prefer the already-pinned unstable 2.6.0 package
rather than the root stable 2.4.0 package, subject to module/package evaluation.
No blanket nixpkgs update is proposed.

## Proposed phases

1. **Service foundation:** `modules/hosted-services/vikunja/nas.nix`, native NixOS
   service with selected package, allocated loopback port, explicit `tailnet = true`
   at `todo.bepis.lol`, closed registration/account bootstrap, runtime secrets, and tested
   database plus attachments backup/restore. SQLite is a simple candidate, not a
   decided requirement. Evaluate configuration; builds/deployment require approval.
2. **Shared integration and NAS interface:** one separately owned Vikunja client/tool
   package, not two implementations. NAS primary conversational interface; GRILL
   projects opt in to the same package. Add dedicated NAS managed-room support rather
   than extending the existing restricted NAS chat assistant. Provide restricted and
   operator-selected full-access GRILL configurations. Keep credentials out of tool
   arguments and model-visible results. Normal managed sessions retain host-user
   authority: project bindings and API tokens are not OS sandbox isolation.
3. **Initial useful workflows:** capture into Inbox, project/sub-project organization,
   search/read, create/edit/complete, due dates, labels, comments and task relations.
   Explicit project bindings for coding workspaces; no guessed project destinations.
   Include direct deletion and user-directed bulk operations without additional
   confirmation gates. Use conditional updates, bounded results and no blind mutation
   retries. Reject stale or invalid writes rather than silently overwriting conflicts;
   this is data-integrity validation, not an approval gate. Treat task text as untrusted
   content, never as authorization.
4. **Deferred automation:** no scheduled reviews, proactive reminders, webhook workers
   or autonomous task execution in this implementation. Agents may use the low-level
   tools for reviews or organization when the user asks; native application features
   do not imply permission to schedule agent runs.
5. **GitHub replacement experiment:** one disposable pilot project; map parent tasks,
   blockers, readiness, provenance/idempotency, claiming, verification and closure.
   Keep existing GitHub tools and aloop unchanged until this is explicitly approved.

## Deployment details (see implementation guide)

- Dedicated managed sessions are now declared for NAS but have not been activated;
  verify launcher/relay provisioning and credential ownership during deployment.
- Verify token scopes against the selected Vikunja release. Both GRILL profiles
  currently share the same credential/authority; tool-level project restrictions
  need a separate implementation before they can be claimed as enforced.
- Software/Life/Inbox is the suggested initial structure, not a mandatory taxonomy.
- SQLite remains the proposed starting database. Identify backup destination and
  retention before deployment; define attachment limits if attachment tools are added.

## Verification state

Read local configuration, root-input package/module sources and official online docs.
Resolved the two public nixpkgs source paths via fetchTree (evaluation only).
Initial research ran no application tests. Subsequent implementation adds offline
checks documented in the implementation guide. No NixOS configuration evaluation,
builds, activation, live API calls, secret access, or account/room creation were performed. Existing unrelated
changes to `flake.lock` and `modules/services/tailscale-proxy/runtime.nix` were left alone.
