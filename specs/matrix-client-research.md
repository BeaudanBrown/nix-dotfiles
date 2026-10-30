# Matrix QR login and push notifications

Research date: 2026-10-07. No server/client configuration or deployment changes made.

## Scope and confidence

The owner reports “Not supported by your account provider” when showing a QR code in settings, plus a request for a push notification server. The exact client, version, platform, install source, and push warning wording are not yet known. The repository installs Element Desktop (`modules/apps/element/work.nix`), but this does not establish which client produced either message. The UI symptom was not reproduced; the public server capability checks below were reproduced without credentials.

## Live public checks

Commands:

```sh
curl -sS https://matrix.bepis.lol/.well-known/matrix/client
curl -sS https://matrix.bepis.lol/_matrix/client/versions
curl -sS https://matrix.bepis.lol/_matrix/client/v3/login
```

All returned HTTP 200. Relevant results:

- Client discovery advertises only `m.homeserver.base_url = https://matrix.bepis.lol/`; no delegated authentication provider is advertised.
- Versions reports `org.matrix.msc4108: false` and `org.matrix.msc3882: false`.
- Login advertises `m.login.password` and `m.login.application_service` only.

Repository evidence: `modules/services/matrix/nas.nix` configures Synapse and three bridges, but no Matrix Authentication Service (MAS) or dedicated push gateway. The module references private extra configuration; that file was not inspected. Public discovery/capabilities describe the deployed client-visible behavior, not the complete private configuration.

## QR login

For Element's QR device-linking/login feature, the observed server capabilities are consistent with the reported unsupported-provider message. QR **login** is distinct from QR **verification** of two existing sessions. Element documents its QR login implementation as requiring server support based on MSC4108; the login-page feature and settings-side “Link new device” flow are distinct entry points. [1]

A modern delegated-authentication deployment using MAS is the normal path to OAuth-based device authorization. This requires configuring MAS/Synapse integration, discovery and the appropriate rendezvous support for the exact client/server versions, not just a client preference. [1,2,3]

Do not treat enabling an experimental flag alone as a complete solution. Before adopting MAS, inventory existing users, bots, access tokens and bridge authentication. The migration guide describes migration of sessions/devices/access tokens and a downtime/backup/cutover procedure. Bridge application-service login has documented limitations that require checking each bridge's version/configuration. [4,5]

Current recommendation: retain password login and existing verification/recovery methods unless QR login or delegated account management justifies a planned authentication migration.

## Push notifications

These are independent of QR login. The Matrix protocol has clients register a pusher with a gateway URL; Synapse delivers notifications to that gateway, which wakes the app through its supported push transport. A self-hosted homeserver does **not** imply that its owner must also host a gateway. [6]

- Official Element mobile builds can use the app vendor's gateway and platform push transport. Sygnal is a gateway implementation, not an automatic fix for any Matrix client. APNs/FCM credentials are application-specific, so a self-hosted Sygnal cannot simply send pushes to arbitrary official app builds. [7,8]
- For Android clients/builds that support UnifiedPush, an installed distributor such as ntfy can provide the transport. ntfy has a built-in Matrix gateway at `/_matrix/push/v1/notify`. Self-hosting ntfy is an option, not a requirement. For restricted ntfy deployments, its documentation describes allowing anonymous writes on UnifiedPush topics (`up*`). [9,10]
- Do not assume all Element/Element X builds support the same notification transports. The notification Markdown currently in Element X's repository describes older Element Android behavior and does not establish current Element X UnifiedPush support. Confirm the actual app/version/build before prescribing ntfy. [11]
- Element Web/Desktop notification settings and operating-system permissions should be checked separately; the desktop client does not require deploying a new mobile push gateway just to show local notifications while running. [12]

If the warning is from an Android UnifiedPush configuration screen, first identify whether a distributor is installed and selected. If it is from an official FCM/APNs build, first inspect notification permissions, push registration diagnostics and connectivity rather than deploying a new gateway. The authenticated `GET /_matrix/client/v3/pushers` endpoint can establish whether that device registered a gateway; do not paste tokens or push keys into research notes. [6]

## Follow-up information needed

1. Exact client name/version and platform.
2. Installation source (Play Store, F-Droid, App Store, Nix package, browser).
3. Screenshot or exact wording of the push warning, without credentials/recovery keys.
4. Whether notifications fail only when the app is in the background.

## Primary sources

1. Element Web labs, QR login: https://github.com/element-hq/element-web/blob/develop/docs/labs.md#log-in-with-qr-feature_login_with_qr
2. MAS authorization/device authorization: https://element-hq.github.io/matrix-authentication-service/topics/authorization.html
3. MAS homeserver integration: https://element-hq.github.io/matrix-authentication-service/setup/homeserver.html
4. MAS migration: https://element-hq.github.io/matrix-authentication-service/setup/migration.html
5. MAS application-service login limitations: https://element-hq.github.io/matrix-authentication-service/as-login.html
6. Matrix pushers/client API and push gateway API: https://spec.matrix.org/latest/client-server-api/#push-notifications and https://spec.matrix.org/latest/push-gateway-api/
7. Sygnal application configuration: https://github.com/element-hq/sygnal/blob/main/docs/applications.md
8. Element custom push gateway: https://docs.element.io/latest/element-server-suite-classic/advanced-configuration/notifications-mdm-push-gateway/
9. ntfy Matrix gateway / UnifiedPush publishing: https://docs.ntfy.sh/publish/#matrix-gateway
10. Element UnifiedPush/ntfy guide: https://docs.element.io/latest/element-support/element-androidios-client-settings/using-unified-push-and-ntfy-for-push-notifications/
11. Element X repository notification document (legacy-content caveat above): https://github.com/element-hq/element-x-android/blob/develop/docs/notifications.md
12. Element Web/Desktop notifications: https://docs.element.io/latest/element-support/element-webdesktop-client-settings/notification-settings/
