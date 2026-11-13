# Temporary native Matrix bridge cutover (#172 / #173)

This is a **deployment adapter**, not a session manager. Pi still owns histories
and execution; tmux still owns presentation. No local Pi/tmux unit depends on
this job. It creates no conversations, windows, rooms, accounts or model turns.

Implementation is not maintenance authorization. The separately approved
migration-only activation used downstream `3faed95` and harness `7f32929` on both
grill and NAS. Completion/readiness, pristine imported ledgers and frozen backups
were verified; the operator's privileged NAS original/account comparison passed.
Newer grill history appends and the follow-up session remain authoritative and
must not be replaced with captured bytes. Legacy account pending work stays held.

The normal checkout now carries this exact adapter and published harness pin,
reconciled with newer unrelated host/tooling changes. Build approval does not
approve another activation, consumer startup, journal recovery or synchronization
restoration. Keep `startAfterMigration = false` and `holdSynchronization = true`
until the corresponding separate approval. The first-migration sequence below is
historical procedure, **not a command to rerun migration or create fresh permits**.
Later boots/rebuilds recognize completion as described below; they do not compare
or restore legitimately changed original histories.

## Three options

`services.piNativeCutover172` is disabled unless explicitly enabled. Grill/NAS
currently opt in with `startAfterMigration = false`:

- `enable`: install the temporary root `pi-native-cutover-172.service` oneshot,
  old user-unit masks, and new-consumer startup conditions.
- `startAfterMigration` (default false): separate startup approval. False blocks
  the native bridge and NAS assistant **before** sandbox/StateDirectory setup,
  not merely before their main executables. True starts only the replacement
  consumers after durable migration readiness. It never starts native Pi.
- `holdSynchronization` (default true): declare only `state-sync` paused. Keep
  this true until cross-host restoration is approved. Setting it false/removing
  the module releases the declarative hold and may restore baseline sync policy.

A normal rebuild is not proof of idleness or permission to interrupt work. Nix
activation itself can stop/restart changed old services before this job runs.
The prerequisites below therefore apply **before switching**, not just before
conversion. The job cannot make an unsafe rebuild safe after the fact.

## Minimal maintenance sequence

1. Prepare/build the exact reviewed candidate when build preparation is approved.
   Confirm an independent grill terminal and NAS sudo path; this conversation
   will disconnect when its Pi exits. No second assistant is necessary.
2. Under the approved maintenance scope, finish/close affected Pi writers,
   account for finite creators and uncertain external effects, and pause
   `state-sync` on **both** hosts. Account for in-progress scans/transfers too.
   Use existing consent-gated/native closure controls. Leave shared tmux, its
   unrelated shells, and unrelated workloads running. Do not cancel/replay
   pending or ambiguous work to make the check pass.
3. On each host, the candidate's `pi-native-cutover-172 permit-text` prints a
   **read-only template**, bound to its full configuration and implementation
   hash. Only after step 2, the operator installs those exact bytes at
   `/run/pi-native-cutover-172-approved`, root-owned, mode 0600, less than one
   hour before the job starts. Creating that file attests the prerequisites;
   printing the template does not. Never reuse another revision's template.
4. Perform the approved switch with startup still false. PID1 runs the job
   independently of the old conversation. It stops only the named old consumers,
   verifies known process exits with pidfds and cgroup checks, copies/converts,
   and leaves the replacements off. Inspect the private migration report and
   NAS request/account/journal continuity before approving startup.
5. In a separately approved deployment, set `startAfterMigration = true`.
   Completed conversion is recognized without reimporting. Resume original
   histories/rooms and perform the #172 canaries. Restore synchronization only
   under its own coordinated approval; host-local writer locks do not prevent
   concurrent use of the same synchronized history on another machine.

The job never stops Pi/tmux or calls legacy conversation repair/stop APIs. It
refuses known Pi/Git/setup activity, unknown process evidence, live consumer
helpers other than the old relay lock helper, or unconfirmed local pause state.
The job and operator precheck share `require_paused()`. It uses Syncthing's
`--home=CONFIG_DIRECTORY`: this CLI rejects `--config` unless `--data` is also
provided. A successful query returning false still blocks maintenance; fixing
CLI syntax does not pause the folder or attest settled transfers.

These probes are supplementary: names, quiet inventories, control ACKs and a
configured pause flag are **not exhaustive writer/creator/transfer closure**.
The operator's cross-host evidence remains necessary. The conservative probe
also rejects ephemeral Pi helpers; supervise from the independent terminal.

## What is retained

The root-owned control parent is `/var/lib/pi-native-cutover-172` on each host:

- `source/`: independent private copies of complete configured roots, empty
  directories, opaque NAS databases/journals, and `source.json`. Copy staging and
  every copied inode are root-owned from creation; the parent is protected too.
- `bundle/`: sealed root-owned export. Source and bundle are frozen to directory
  mode 0550 / file mode 0440, readable only by root and the temporary private
  `pi-native-cutover-172` group (whose only configured member is the owner).
  The owner cannot chmod/replace their input or retain a pre-freeze writable FD.
  Kernel-readonly namespace views remain mandatory; `/dev` stays available.
- `complete.json`: public, root-owned completion identity (no history content),
  bound to the original imported ledger inode and converter receipt digest.
- `run.lock`: excludes another invocation of this job, not other history writers.
- Unpublished `.source-partial-*`, export/import partials and receipt partials:
  preserved, never adopted, overwritten or automatically deleted.

`inventory`/`export` run as the capture authority; they do not open a runtime
writer. `import`/`check` run as the native owner with the private capture group as
primary, so they retain read access across namespace setup. Both use a clean
environment. The job verifies capture/export/import/check digest continuity and
rechecks the frozen source against originals immediately before conversion.
There is no user-owned mutable-export adoption or in-place ownership repair.

The active ledger remains at the native module's distinct state directory,
normally `/home/beau/.local/state/pi-matrix-bridge`. Histories remain at their
**original paths**. No authentication directory is copied. Original ownership
and journals are not repaired or changed by the capture script. The temporary
NAS tmpfiles exclusion covers only `/var/lib/pi-chat-files`; an already-running
cleanup blocks capture rather than being killed.

The converter supplies `migration-report.json` and `migration-receipt.json` in
the active state. Unique current-file IDs are mapped from copied headers;
canonical Git common-directory/checkouts are queried read-only as the owner.
Unproven grouping stays held, never guesses replacement Spaces. Missing/corrupt,
retired/departed/private identities and ambiguous deliveries retain the
converter's existing non-resurrection/hold behavior.

## Failure, retry, and later boots

Failure leaves the replacements gated off; old consumers are not automatically
restarted. Do not erase evidence, unmask old authority, or restore stale queues.
Fix forward or explicitly continue locally under #172's approved scope.

A retry **before completion** needs fresh valid maintenance evidence and compares
all original roots with the published capture. A complete pristine import may
be recognized after losing completion publication. Changed, foreign, started,
partial or inconsistent state is refused. Partial stop can cause downtime;
timeout/caller exit is not cancellation of external work.

After completion, later boots/rebuilds validate only the root completion and
current destination identity. They do not invoke the converter, require the old
snapshot, or compare legitimately changing original histories. Ledger content
and WAL activity may evolve normally; replacing the ledger/receipt requires
explicit reconciliation, not automatic reimport.

`/run/pi-native-cutover-172/ready.json` is root-owned and boot-scoped. Revalidation
first withdraws old readiness. Sandboxed NAS gates read this public authority
without acquiring access to the owner's home; the native bridge gate additionally
checks its ledger identity. There is no invalid system-unit dependency in a user
manager. Approved startup uses systemd start requests, not process replacement.

After #172 acceptance, explicitly remove the temporary host enables/module/gates
and scoped cleanup exclusion/private reader group under a coordinated deployment.
Retained captures remain root-readable afterward. Do not delete old
state, histories or captures as part of removal. This adapter's additional
production lines are temporary cutover scope, **not included in the earlier
7,990-line release accounting**; update final accounting after its removal rather
than claiming that historical budget still describes this candidate.

## Verification scope

`test-cutover-172.py` uses disposable roots, fake process/service observations,
actual pidfds on its own child, injected failures/SIGKILL on its own fixture
children, and the actual pinned converter plus bubblewrap. Fixture authority and
owner roles share the test UID; root ownership/reader-group declarations are also
evaluated in Nix, not claimed as a privileged boot integration. Required environment:
`CUTOVER_FIXTURE`, `CUTOVER_CONVERTER`, `CUTOVER_BWRAP`, `CUTOVER_SYNCTHING`;
missing tools fail, not skip. The real pinned Syncthing CLI tests generate only
disposable device identities, use an authenticated synthetic HTTP API, require
GET-only traffic and unchanged configuration, and distinguish paused=true,
paused=false and HTTP refusal. The API fixture includes normalized empty
maps/slices like upstream `Configuration.Copy()`; an incomplete response can
spuriously trigger the CLI configuration editor's write-back branch.
`test-cutover-module-172.py` evaluates both complete host derivations and off/on/
disabled gate variants without building or activating them.

`test-cutover-vm-172.nix` adds a booted, disposable NixOS test with real PID1,
root/UID-1000 separation, the actual converter/bubblewrap, private reader-group
permissions, a loaded synthetic legacy consumer, pre-StateDirectory gates,
reboot without snapshots/reimport, and separately enabled sandboxed consumers.
The VM uses the real Syncthing CLI through the actual root/runuser boundary,
against that synthetic API; consumer bodies remain synthetic. No real accounts,
histories or credentials enter the VM. Supply `nixpkgs`, `fixturePath` and
`bridgePath` as explicit pinned Nix arguments; this test builds a VM and therefore
requires build authorization.

This test caught an evaluation-only blind spot: nested `environment.etc` masks
cannot be installed beneath NixOS's generated `/etc/systemd/user` symlink. The
adapter now uses native `systemd.user.units.<name>.enable = false` masks; the
complete generated tree and effective masks are exercised by the VM.

None of these checks proves actual NAS capture, cross-host quiescence, live
Matrix/model/NAS acceptance, or downgrade compatibility for every real history.
Those remain explicit #172 evidence.
