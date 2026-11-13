# #172 grill startup candidate — not activation approval

This isolated candidate changes only grill's temporary cutover options to
`startAfterMigration = true` and explicitly retains `holdSynchronization = true`.
It keeps the published harness, converter, imported destination and completion
identity unchanged. NAS retains `startAfterMigration = false` and its existing
chat/model/bridge holds. Both hosts' state-sync folders stay paused.

The normal held source at `8a48b3d` remains available independently. Preparing or
building this candidate is not permission to switch either host, start a bridge,
contact Matrix, resume synchronization, create permits or rerun migration.
The candidate must be activated only through a separately approved exact-output
batch after fresh read-only checks of both hosts. No ordinary mutable-source
`nh` invocation belongs in that batch.

## Startup scope, not a room-exclusive mode

The existing bridge has one host-wide sync/delivery/organization loop. Starting
it can affect every eligible grill binding; the original room selected for the
canary is a test target, **not a runtime allowlist**. After fresh sync fences
clear, fresh participant input in other enabled rooms may wake native Pi too.
Background work can verify original room policy, send interrupted-input notices,
project eligible post-conversion human-visible output, and reconcile existing
Spaces. It must not recreate inaccessible originals, replay held old requests,
restart shared tmux or refresh native Pi automatically. Operator approval must
name this actual scope, rather than promise a single-room-only startup.

NAS's owner-account helper is offline. No automatic account joins or completion
of legacy pending account jobs is part of this step. Keep the 19 pending legacy
account acknowledgements, two outbox records and 18 invitation records as retained
historical evidence. Incomplete grouping and inaccessible/foreign original rooms
remain held, not repaired. Report omission counts are not zero findings.

## Existing completion, no reconversion

The unchanged cutover job may execute its **completed** branch during activation:
validate the root completion and imported ledger inode/receipt, republish current
boot readiness and request the approved native bridge start. It must not enter
preflight/capture/export/import. The operator batch requires an existing valid
completion/readiness pair before activation and never creates a permit. Preserve
all captured originals, newer native history appends and the active ledger.

Opening the runtime ledger sets the permanent migration-started marker. Even a
failed startup then requires receipt reconciliation, not stale queue/history
restoration. Service/socket/window acknowledgements alone do not prove Matrix
delivery, model completion, external tool effects or process exit.

## Canary acceptance after separate execution approval

Use a named original enabled room/native identity and a fresh caught-up
`!status` before test instructions. Verify immutable original-room creator/policy
and imported-room receipt, fresh-input fence, held old-input/poll state, unchanged
room/native identity, and fresh text/reply round-trip. `!status` alone is not a
model/delivery canary. Do not archive/restore, create task workspaces or deliberately
interrupt another user's work as an incidental test. Media, collaborator/poll,
picker/reattachment and NAS invitations/chat remain explicit follow-on acceptance
items unless separately included.

On failure, preserve logs/receipts/new work and do not rerun activation, migrate,
repair accounts, roll back, unmask legacy consumers or resume replication blindly.
Stopping only the new grill bridge can be an explicitly approved containment action;
it does not imply cancellation of native turns, tools or child processes.
