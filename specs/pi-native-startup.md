# Normal native startup after migration (#172)

Grill and NAS completed the one-time migration. Their host modules now import
`native-retention.nix`, not `cutover-172.nix`. The migration job, installed
migration wrapper and consumer completion/readiness gates are absent. Native
bridge and NAS owner-chat services use their ordinary package startup behavior.
No migration runs on boot, and no new permit or receipt rewrite is required.

The old guard persisted database `st_dev`, which is not a stable Btrfs identity
across boots. Grill's configuration identity, inode and receipt still matched,
but device50 became52 after a subsequent boot. Retirement does not assert that
inode/receipt equality alone proves full database contents; earlier successful
migration and live acceptance evidence remain necessary. It does not replace
this brittle check with an automatic adoption or reimport mechanism.

## Protections that remain

- Both `state-sync` folders stay declaratively paused. Restoration requires a
  separately approved fleet-wide writer/divergence assessment.
- Both legacy relay/rollout user units remain masked.
- Frozen-capture group and access are retained. Original histories, backups,
  completion/import receipts and live bridge/account state are not deleted,
  moved, rewritten or recursively re-owned.
- NAS `/var/lib/pi-chat-files` remains excluded from age-based tmpfiles cleanup.
- Bridge runtime access, private-state and native writer-lock checks remain.
- Current harness pin, Matrix identities, enrollment roots and explicit
  `~/documents/projects` fresh-project destination remain unchanged.

Historical cutover source and tests remain in Git for evidence. They are not
imported by either host or installed as a host command. Do not invoke them on
live state. Removing the old systemd unit may remove its ephemeral `/run`
readiness directory; persistent `/var/lib/pi-native-cutover-172` is retained.

## Verification and activation

`python3 modules/cli/pi-harness/test-native-retention.py` evaluates both hosts,
checking absent migration service/conditions/executable, normal startup,
independent retention and unchanged project/enrollment settings. It does not
build or activate. Full host outputs are built separately with operator approval.

Activate only the reviewed exact store outputs from an independent terminal
with idle bridge/chat work. A full-system switch may restart bridge, owner chat,
DBus and polkit, but must not stop independent Pi/tmux processes. Capture process
identities before switching and verify actual exit of replaced bridge/chat
processes, service readiness, legacy masks and actual sync pauses afterwards.
Do not use the old migration gate as post-switch acceptance: it is deliberately
absent. Do not replay old messages. Use a fresh harmless native/owner-chat canary.
Existing Pi extensions remain loaded until a separately safe session refresh.

If activation fails, preserve state and inspect; never blindly roll back to an
importer-capable old generation, unmask legacy units, restore old histories or
repair receipts. NAS account invitations/SDK state stay independent and intact.
