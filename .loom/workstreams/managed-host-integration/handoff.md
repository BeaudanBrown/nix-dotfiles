# Managed host integration — harness #120

## Authorization and state

Operator approved source-only configuration/package/keybinding work and local
commits in this worktree. No external Nix evaluation/build, push, activation,
service/shared-tmux restart, live Matrix traffic, or secret access. Harness #120
is claimed. This is preflight, not implementation or deployment evidence.

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
1. Publish/select a compatible harness input and validate the fleet configuration
   under separate permission. Current lock still selects 1604a971d5990e520399186de7dd90a7071dca65;
   do not invent a replacement narHash or claim this old pin supplies new options.
2. Verify the three exact Matrix device IDs before enabling account effects.
   Public host and bot names do not prove token/device identity.
3. Retain existing host/account journals, receipts, retirement tombstones and
   native histories together; never change device scope under a live journal.
4. Respect existing update guards and pinned busy runtimes; no automatic adoption,
   restart, migration or destructive rollback. Migration needs a fresh preview
   and confirmation, not merely service activation.

## Missing non-secret configuration

The inspected public source contains no device IDs for:
- the existing dedicated NAS owner login (@beau:matrix.bepis.lol, pi-chat token);
- the @pi-grill:matrix.bepis.lol bot login;
- the @pi-nas:matrix.bepis.lol bot login.

Upstream managedSessions.accountDeviceId is the owner recipient; NAS
bridgeChat.assistant.managedAccountHosts requires exact hostId/botUserId/deviceId
triples. Need operator-supplied IDs, or explicit approval to stage account wiring
with effects disabled until verified IDs are supplied. Do not read credentials,
query live accounts, infer IDs from display names, or use wildcard trust.
