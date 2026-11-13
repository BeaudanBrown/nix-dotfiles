# Preparing to synchronize Git metadata

Status: draft; inventory and recovery gates must be completed before enabling anything.
No configuration changes, service changes, or migration are authorized by this plan.

## Configuration findings

Reviewed `modules/services/syncthing/{main,nas}.nix`,
`modules/cli/git/minimal.nix`, and `modules/host-spec/all-hosts.json`.
These are source findings, not confirmation of deployed settings.

- The `main` root currently applies to grill, nas, laptop, and t480.
- `documents` (`txxit-w9cwz`), `monash` (`twjfr-ekoqc`), and `collab`
  (`vccfp-s5yfe`) all receive `(?d)**/.git` from `sourceTreeIgnorePatterns`.
  Removing this one rule would expose Git metadata across all three folders.
- Those folders share with Syncthing devices `server`, `grill`, `laptop`, and
  `t480`; `collab` additionally shares with `lachy-thinkpad`. Confirm that
  `server` is NAS by comparing live device IDs; the alias alone is not proof.
- Most configured devices automatically accept folders. Do not introduce a
  pilot folder until auto-accept behavior on every connected peer is contained.
- `documents` also excludes `/projects/dump`, an NFS-backed path on GRILL.
  Preserve this exclusion; do not traverse that mount during repository discovery.
- Source folders also ignore `(?d)**/*.sync-conflict-*`. Existing conflict copies
  must be inventoried explicitly rather than assumed visible on every device.
- No folder versioning is declared in these Syncthing modules. Live settings may
  differ. Versioning alone would not provide a coherent Git backup anyway.
- `state-sync` uses a separate ignore list. The pending `mobile` folder has no
  source-tree ignore list; do not assume `.git` is excluded there already.
- The reviewed Git module declares no automatic-maintenance policy. Other
  configuration, IDEs, Git defaults, or scheduled jobs may still run maintenance.

## Safety model

Syncthing copies files; it does not merge Git refs or atomically replicate a
repository. Different device copies can contain unique commits, reflogs, stashes,
and uncommitted work even when their working trees look identical.

There is no unconditional no-history-loss guarantee for live multi-writer `.git`
synchronization. Prefer Git remotes for exchanging history, retaining the `.git`
ignore. If metadata synchronization remains the goal, require one active writer
per repository across the entire fleet, explicit handoffs, and independent backups.
Local Git locks do not provide a cross-device lock. A send-only device is not a
Git-aware transaction boundary either.

## Phase 1 — Read-only inventory (next step)

1. Confirm all devices that have ever held these folders, including offline or
   retired devices and lachy-thinkpad. A disconnected device is an unresolved
   source of history, not an empty copy. Keep it isolated until inspected.
2. Record each device's live folder IDs, paths, folder types, ignore rules
   (including includes), versioning, sync errors, and device membership. Do not
   publish API keys, credentials, remote URL tokens, or private repo contents.
3. Discover repository boundaries in the three source folders without following
   symlinks or crossing mounts. Prune `/projects/dump` and never enter the private
   `sops-secrets` repository. Identify ordinary `.git` directories, `.git` pointer
   files, nested repositories, bare repos, submodules, and linked worktrees.
4. For each repository/device, record relative path, resolved Git/common directory,
   HEAD, refs and object IDs, stash refs, shallow/partial-clone status, alternates,
   LFS use, worktree links, and whether staged/unstaged/untracked work exists.
   Do not automatically read arbitrary Git config or dump diffs into public logs.
5. Group matching repositories by identity/history, not pathname alone. Flag
   unrelated histories at the same path, missing copies, and existing corruption.

Deliverable: a private per-device inventory and a coverage table. No enabling
change until every device is accounted for or explicitly quarantined.

## Phase 2 — Freeze and preserve every independent copy

1. Schedule a maintenance window. Pause affected folder synchronization on every
   participating device and verify that it is paused. Quiesce Git writers,
   IDE background Git, agents, fetchers, and maintenance/GC. Do not kill sessions
   or stop services without separate approval. Do not run prune, reset, clean,
   reflog expiry, or conflict cleanup.
2. Before manipulating any copy, archive each device's complete working tree and
   Git metadata to a host/date-specific location outside every synchronized root.
   Include ignored/untracked work, index, reflogs, loose objects, packs, and Git
   directories referenced from outside the checkout. Preserve symlinks/modes.
   Include external alternates and locally available LFS objects where applicable.
   Never inspect or back up the private secrets repo through this workflow.
3. Keep at least two independent backup copies, one outside the sync fleet, with
   restricted access, capacity checks, checksums, and a repository/device manifest.
   Btrfs storage is not evidence that snapshots or independent backups exist.
4. Restore a sample, then each repository's metadata, in an isolated location.
   Run `git fsck --full` on restored copies. Record missing/corrupt objects versus
   merely dangling objects; shallow/partial clones need separate interpretation.
5. Make portable `git bundle create ... --all` exports from isolated copies where
   supported and verify them. Bundles are supplementary: `--all` does not preserve
   reflog-only/unreachable objects, working changes, external LFS payloads, or the
   complete original metadata. An empty repository may have nothing to bundle.

Gate: checksummed raw backups and demonstrated restores for every independent
copy. Existing integrity failures block migration pending recovery investigation.

## Phase 3 — Reconcile history without overwriting originals

- Work only in an isolated staging repository outside synchronized paths.
- Import each device's refs into distinct, recorded recovery namespaces. Preserve
  each device's HEAD (including detached HEAD), branches, tags, remote refs, and
  stash tips; do not let matching names overwrite another device's tips.
- From restored copies, enumerate reflog-only commits and recoverable dangling
  commits and give desired tips durable recovery refs before any cleanup. Retain
  raw archives regardless; non-commit objects can also represent valuable work.
- Confirm every inventoried tip exists and is reachable in staging. Fetch missing
  promised/shallow history where possible; do not claim complete history otherwise.
- Resolve canonical branches/tags and working-tree changes explicitly with the
  owner. Keeping recovery refs preserves divergent history without forcing a merge.
- Exclude linked worktrees, external Git directories/alternates, partial clones,
  and other special layouts from the first rollout until individually designed.
  Inspect hooks/config locally for unsafe or host-specific settings before reuse.

Gate: per-device tip accounting, integrity checks, and an approved canonical copy
for each repository, with unchanged originals still recoverable.

## Phase 4 — Disposable pilot, then controlled seeding

1. Test with synthetic history and two explicitly selected devices in a separate
   folder, not by removing the shared ignore. Contain auto-accept first.
2. Exercise commit/branch/tag/stash creation, rename/deletion, handoff, offline
   reconnect, repacking, and an intentional conflict using disposable data only.
   Check complete convergence and `git fsck --full` after quiescence, and test restore.
   Passing a pilot is not proof that concurrent Git writes are safe.
3. Design an opt-in per-folder/per-repository rollout; keep `.git` ignored elsewhere.
   Do not blanket-ignore lock files or Git internals as a substitute for consistency.
4. With every real writer and affected folder paused, preserve and move old copies
   out of synchronized paths, then seed identical approved metadata on selected
   peers. Account for the working tree and index as well as `.git`. Do not expose
   divergent originals to Syncthing and hope it chooses the right files.
5. Enable only the selected scope on selected devices, verify convergence, refs,
   integrity, and conflict/error absence, then admit additional peers one at a time.
   No "Override Changes" or "Revert Local Changes" without a reviewed recovery plan.

## Ongoing operation and rollback

- One active repository writer at a time, including automated jobs. Before changing
  devices: stop writers, wait for full convergence, check errors/conflicts, then
  hand off. Never write from two offline devices and later reconnect them.
- Keep independent, tested backups. Syncthing versioning archives remote changes,
  not all local changes, and is not a transactionally consistent repository backup.
- On any mismatch or corruption: pause affected folders on all peers, quiesce
  writers, preserve incident copies separately, then restore/reconcile in isolation.
  Re-adding the ignore alone neither undoes received changes nor recovers history.
- If this operating discipline is impractical, keep `.git` excluded and use Git
  transport for history instead. That is the recommended lower-risk outcome.

## Decisions needed before execution

- Is the goal whole-checkout handoff, including index/stashes, or simply making all
  commits available everywhere? The latter is better served by Git remotes.
- Which devices still have copies, and which are currently offline?
- Where should independent backups live, and how much capacity is available?
- Can every writer, including agents, follow a single-writer handoff?
- Which noncritical repository and two devices should pilot first?

## References

- [Syncthing synchronization and conflicts](https://docs.syncthing.net/users/syncing.html)
- [Ignore semantics](https://docs.syncthing.net/users/ignoring.html): `(?d)` permits
  deletion of ignored items that block directory deletion; it is not a backup flag.
- [Versioning limitations](https://docs.syncthing.net/users/versioning.html)
- Related fleet state conventions: [modules.md](./modules.md) and
  [pi-session-sync.md](./pi-session-sync.md).
