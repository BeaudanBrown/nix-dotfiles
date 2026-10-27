# Managed host integration — harness #120

This preserves the original source-only #120 handoff below. Subsequent #121
cumulative review and separately authorized standalone candidate builds/private
smoke are recorded in `../managed-smoke/handoff.md`. The current harness revision
is now **692426351a318a56422f7a38b78ce2ea3c80af7f**, published and resolved in the
actual feature-worktree lock under explicit steps 1–2 authorization. Only its lock
node changed. Element X functional acceptance passed; the final prose wording
has deterministic/review verification but no fresh phone confirmation. Desktop
checks are deferred, not passed. Neither host has been built or activated.

Publication/lock changes do not merge default branches or affect running systems.
Builds, activation and migration remain separately gated. See the current package
boundary in `specs/managed-live-workspaces.md`.

## Original source-only authorization and state

Operator approved source-only configuration/package/keybinding work and local
commits in this worktree. No external Nix evaluation/build, push, activation,
service/shared-tmux restart, live Matrix traffic, or secret access. Harness #120
is claimed. Source implementation a210735, affected tests, paired review and final
harness gate pass. No deployment evidence is claimed; package/lock boundary remains.

Source bases: dotfiles a128141; harness ec7dda8. Existing sources retain GRILL/NAS
host IDs, dedicated relay-bot MXIDs, operator MXID, ignored bridge senders, named
workspace roots, shared-tmux guard and launcher package wiring. NAS assistant
already references its dedicated owner-login token via SOPS; do not inspect it.

## Acceptance / evidence matrix

| Acceptance | Intended change | Permitted evidence |
| --- | --- | --- |
| Approved harness/picker packages and roots | Keep one picker derivation for keybinding and managed launcher; record approved harness revision and staged input transition; preserve configured roots/host identities | Source/package/keybinding assertions; no external Nix evaluation/build |
| NAS deterministic account automation | Configure exact host/bot/device trust pairs and owner recipient device; reuse existing matrixTokenFile reference only | Static allowlist and credential-boundary checks; existing harness account tests |
| Local-only versus local-model; experiments default off | Preserve pi-local -> pi-r-local; expose upstream pi-local-only and explicit experimental entrypoint; explicit default-off options | Source assertions and existing harness command/resource tests |
| Central mutation policy | Use known-action deployment policy defaults (model approval, reads free), existing exact identities, no runtime editor | Compare against harness public policy schema/defaults |
| Preserve existing services and ownership | Leave shared-server guard/NNP scope, retention, coordinator and assistant/file grants intact | Scoped diff/static assertions; no adopted/restarted processes |
| Staged compatibility/migration/rollback | Durable owning-repo runbook, relay/account/adapter ordering, fresh migration consent, backup and unsupported downgrade limits | Source documentation against harness migration/update contracts |

## Deployment/crash boundaries

No persistent runtime operation is authorized here. Future activation must:
1. Publication and exact harness lock resolution are complete at 6924263.
   Validate/build the fleet configuration only under separate permission; a
   resolved input is not evidence of successful host evaluation or deployment.
2. Verify the three exact Matrix device IDs before enabling account effects.
   Public host and bot names do not prove token/device identity.
3. Retain existing host/account journals, receipts, retirement tombstones and
   native histories together; never change device scope under a live journal.
4. Respect existing update guards and pinned busy runtimes; no automatic adoption,
   restart, migration or destructive rollback. Migration needs a fresh preview
   and confirmation, not merely service activation.

## Implemented source and remaining boundary

Operator supplied existing-token whoami results: owner PXZRSYBGDY, GRILL
PI_GRILL_RELAY, NAS LKVMVRCIUY. Both relays now address the owner device; NAS trusts
only the two exact bot/device pairs, retaining the existing owner token reference.
Experiments are explicitly off in normal launches; pi-local -> pi-r-local and the
upstream pi-local-only remain distinct. Runtime retention and central defaults are
explicit. Package checks have real UI dependencies and version floors. Roots,
keybindings, shared server/guard, assistant/file grants and credentials are preserved.

Durable runbook: specs/managed-live-workspaces.md. flake.nix requests harness
ec7dda83ab344283aab9c35e177cc6ba02f7cfe9, but it is local/unpublished and the old lock
remains. This is intentionally unresolved staging, not a buildable configuration.
Do not mark package integration/deployment verified or silently close this boundary.
Publication and real lock resolution require separate permission; no fake hash.

Evidence: seven source assertions and six Nix syntax parses (not evaluation) pass;
65 direct Go race tests pass; harness packaged566 managed/87 bridge pass with zero
skips. An initial ad-hoc Node run skipped12 SDK-dependent cases; the subsequent
packaged suite supplied the real environment and supersedes those skips. Logs in
harness .pi/tmp/workers/2026-10-09T06-22-27-971Z-managed-host-config-source-focused-621bb96a642a/,
2026-10-09T06-22-52-635Z-managed-host-config-affected-dd4e8ae94728/, and
2026-10-09T06-25-23-079Z-managed-host-config-packaged-affected-8c595ab5a669/.

Review: harness .pi/tmp/reviews/2026-10-09T06-31-16-951Z-worktree-2029b59f4515-52b2a67f4dad/.
Standards found no violations and classified unresolved publication/lock as high /
justified deferral; Spec had no findings. A preceding tool failure produced no
report and was retried unchanged. No source remediation was requested.
Final source7 / parse6 and HARNESS canonical12 / production packages passed:
.pi/tmp/workers/2026-10-09T06-32-35-909Z-managed-host-config-final-canonical-a2467039c9d9/.
Managed566, bridge87, package13+17, zero skips. Only evidence prose changed after.
Harness durable evidence: docs/managed-host-integration-evidence.md.

Next boundary: separate permission to publish/select the reviewed harness and
resolve the actual external lock graph. Keep #120 open until that integration
boundary is resolved; #121 cumulative/client acceptance remains unclaimed. No
push, external evaluation/build or live changes have occurred.
