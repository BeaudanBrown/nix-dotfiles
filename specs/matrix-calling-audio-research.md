# Matrix calling and Signal voice-message crash

Research date: 2026-10-09. No Matrix configuration, builds, deployment or client
changes made. OnePlus Termux SSH authorization was separately committed and
pushed as `b90539a`; its commit/push hooks passed.

## Element X Android audio crash

The user reports Element X 26.09.4 on LineageOS crashing when playing audio from
a Signal-bridged room. An exact upstream symptom match exists:

- [Element X Android #7812](https://github.com/element-hq/element-x-android/issues/7812),
  “Trying to listen to an audio message bridged from Signal insta-crashes the app.”
  The reporter used 26.09.3 and could play recordings made in Element X, but not
  Signal-origin recordings. Reported September 29; closed October 2 as completed.
- Its linked fix, [PR #7836](https://github.com/element-hq/element-x-android/pull/7836),
  merged October 2, guards invalid waveform playback progress/speed and nonpositive
  durations before rounding the animation duration. The author identifies
  converting `Float.NaN` to `Int` as the crash mechanism.
- The [26.09.4 release](https://github.com/element-hq/element-x-android/releases/tag/v26.09.4)
  was published September 29 and is an unrelated room-list hotfix. Direct inspection
  of [its waveform source](https://github.com/element-hq/element-x-android/blob/v26.09.4/libraries/designsystem/src/main/kotlin/io/element/android/libraries/designsystem/components/media/WaveformPlaybackSync.kt)
  confirms the guards from #7836 are absent. The GitHub releases endpoint still
  listed 26.09.4 as the latest published release when checked; do not claim an
  available newer stable release already contains the fix.

This is a strong explanation for the user's symptom, **not a confirmed local
crash diagnosis**: no phone crash trace, media file, or agent-runnable reproduction
was available. Do not conclude that Signal's media bytes are corrupt or that
LineageOS codecs caused it. The demonstrated upstream bug is client-side playback
UI arithmetic, not Synapse, push notification transport or MatrixRTC.

Next steps:

1. Prefer an official Element X release explicitly containing #7836 once available.
   Do not suggest reinstalling/clearing storage or changing the server to fix this.
2. Until then, play the recording in native Signal, or another trusted player/client
   if a safe download/open action is available. Avoid unknown APKs or public uploads
   of private voice messages.
3. If a fixed release still crashes, capture the Android fatal exception or send
   an Element X bug report referencing #7812. A trace naming
   `remainingPlaybackAnimationMs` / NaN rounding would corroborate this diagnosis.
   Compare an Element-origin recording against a Signal-origin recording.

A less exact related report is
[#5964](https://github.com/element-hq/element-x-android/issues/5964) on OnePlus 8T,
LineageOS 23/Android 16, but it concerns recording/preview/sending, not receiving
Signal audio. It is not the best match. The
[mautrix-signal changelog](https://github.com/mautrix/signal/blob/main/CHANGELOG.md)
also has an old 0.6.2 Element X voice-message rendering fix; the pinned nixpkgs
package is already 26.09, so that old bridge upgrade advice is not applicable.
The actual deployed bridge version was not verified.

## Enable Matrix-native calling

Repository search found no LiveKit, MatrixRTC authorization service or coturn
configuration. `modules/services/matrix/nas.nix` configures Synapse and bridges,
with only MSC3202/MSC2409 enabled explicitly. On the deployed public endpoints:

```sh
curl -sS https://matrix.bepis.lol/.well-known/matrix/client
curl -sS https://matrix.bepis.lol/_matrix/client/versions
```

Discovery returned only `m.homeserver`; versions advertised MSC4140 and MSC4143
as false. This is consistent with calling infrastructure not being configured;
private Synapse extra settings were not inspected.

For Element X, follow the current official
[Element Call self-hosting prerequisites](https://github.com/element-hq/element-call/blob/main/docs/self_hosting.md):

- Deploy a dedicated **LiveKit SFU** plus **lk-jwt-service** (MatrixRTC
  authorization). Keep their shared API credentials in SOPS, not the Nix store.
- Add HTTPS routing for JWT authorization and WebSocket SFU signalling, e.g.
  `rtc.bepis.lol/livekit/jwt` and `/livekit/sfu`. Handle path-prefix stripping
  as the official guide requires; a generic root reverse proxy alone is not enough.
- Provide reachable WebRTC media ports and an appropriate TURN fallback for
  restricted mobile/Wi-Fi networks. TLS/WebSockets alone cannot carry the full
  default media path. Choose ports and NAT/advertised-address settings against
  the actual LiveKit version and NAS/router topology before implementation.
- Configure Synapse MatrixRTC transport discovery, delayed events and the
  supported experimental features for the pinned Synapse/client versions.
  Current upstream documents `msc4143_enabled`, `msc4222_enabled`, delayed-event
  duration/rate limits, and `matrix_rtc.transports`. MSC3266 is needed for standalone
  knocking/room-summary flows. Preserve this repository's existing message limits
  rather than blindly replacing them with the example defaults.
- Ensure OpenID validation works; Synapse already has a federation resource on
  its listener in the repository. The JWT service needs to reach it.
- Check older-client discovery requirements such as
  `org.matrix.msc4143.rtc_foci` in `.well-known/matrix/client` against the actual
  supported clients. Current upstream prefers the Synapse transports endpoint;
  do not assume `.well-known` alone is sufficient.

An additional standalone Element Call website is optional for ordinary in-app
calling. Coturn alone would not enable modern Element X MatrixRTC calling.

### Scope and network decision

These are **Matrix-to-Matrix calls**, not calls to Signal contacts through the
bridge. The mautrix-signal
[features/roadmap](https://github.com/mautrix/signal/blob/main/ROADMAP.md) lists
voice notes/media, not live call bridging; the changelog's call notices are not
media call support. Do not promise Signal live calls from deploying MatrixRTC.

A tailnet-only RTC backend is possible for private participants, but every
participant must be able to reach it (including media paths). For calls with
ordinary federated Matrix users outside the tailnet, plan reachable public RTC
endpoints/media ports with authorization and abuse controls. ntfy being private
does not require the calling backend to be private.

Before implementing, choose public/federated versus tailnet-only calling, confirm
NAS media capacity and router forwarding, and identify client interoperability
requirements. Test locked-screen incoming calls separately from call media: push
notifications and MatrixRTC are different systems.
