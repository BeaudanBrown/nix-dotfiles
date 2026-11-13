# #172 NAS startup candidate — preparation is not activation approval

This isolated candidate enables NAS `startAfterMigration` and explicitly retains
`holdSynchronization = true`. Grill's already accepted configuration is unchanged.
Both state-sync folders stay paused. The normal source remains at promoted
grill-startup `3db870e` until a later approved NAS source promotion.

## Actual startup scope

The existing option permits all three NAS consumers: native host bridge,
owner-account `!pi` transport and SDK model worker. The bridge syncs and organizes
all eligible NAS bindings; a chosen original room is only a test target, not a
room-exclusive runtime mode. Fresh input after caught-up fences may wake native
Pi in any eligible NAS room. Existing native writer locks still apply; service
startup is not authority to restart Pi/tmux or invent replacement histories/rooms.

The separate transport uses the existing dedicated owner credential for
`@beau:matrix.bepis.lol`. It observes its configured allowlisted stateless room
`!XljGtOqHxkwHiILSto:matrix.bepis.lol`; `allJoinedRooms = false` and no remote owner
puppet IDs are configured. Its existing model is `gpt-5.6-terra`, with the original
NAS Pi authentication directory/shared lock. Do not copy credentials, create a new
login or silently choose a fallback model if entitlement fails.

**Existing capabilities are not merely text replies.** The same allowlisted room
has enabled file download/send tools and the dump-site workspace plus immutable
`check`, `publish` and `status` commands. Fresh authorized requests there can edit
and publish dump content without another per-request approval. The workspace
executor is already active independently. This candidate does not widen these
grants, but activating the transport/worker makes them usable again; the later
operator decision must acknowledge that authority. The proposed first canary must
explicitly request no tools or file changes, not exercise publication incidentally.

## Account and invitation boundaries

The owner token has account-wide authority; application allowlists are not token
scoping. The same transport also starts trusted first-invitation handling for
exact `grill -> @pi-grill:matrix.bepis.lol` and `nas -> @pi-nas:matrix.bepis.lol`.
It can accept matching native-room/Space invitations as the owner, after current
immutable creator/provenance/membership checks. Initial catch-up and uncertain
join outcomes use the existing no-replay rules; departed/banned accounts must not
be automatically rejoined or repaired. No leave/forget/unban/notification repair
or generic account scheduler is introduced.

A new `bridge-invites.sqlite` journal/cursor is independent of `requests.sqlite`.
The historical `managed-account.sqlite` is retained, not loaded as an executable
queue. Its 19 pending acknowledgements, two outbox records and 18 invitation
records remain historical evidence. Preserving them is not a promise that the new
invitation consumer resumes those jobs or imports old departure preferences.
Current Matrix policy/membership must be checked under approved live acceptance.
The earlier privileged original/source/bundle account-byte comparison passed;
no new privileged-original or credential read is implied by this preparation.

## Migration and activation

The converter/runtime implementation, destination inode/receipt seam and original
native/account roots are unchanged. Later activation may execute the completed
cutover branch to validate existing completion, publish boot readiness and request
consumer startup. It must never create a fresh permit or recapture/import old
histories. Preserve newer histories and all receipts. Starting a runtime writer
can end the pre-start rollback shortcut even if startup/model/transport later fails.

Only a separately approved exact already-built NAS output may be activated. Review
its full-system delta against the installed held NAS generation, including the
preserved newer Immich nginx upload-limit change and system-path restart triggers.
This is not just three service starts. Keep grill running and replication paused;
never use failure as permission to reset databases/auth, replay requests, repair
accounts, unmask legacy authority, roll back histories or resume synchronization.

## Acceptance after separate execution approval

Test NAS's original enabled native room with a fresh caught-up `!status` and an
explicit harmless fresh message/reply. Verify original native/room identity and
no old-request execution. Then wait for the transport's discard-only watermark
initialization and test one Matrix-origin owner `!pi` in the existing allowlisted
room, requesting no tools/file changes. Process active/socket ready/watermark
stage alone does not prove provider/model or delivery success.

Trusted invitation, media, collaborator/poll, native picker/reconnect, task/archive,
file/workspace/publication, linked Signal/Facebook and coordinated synchronization
acceptance remain separate named canaries. Do not widen rooms or change model/auth
just to force a pass. Keep #172/#160 open until the agreed acceptance is complete.
