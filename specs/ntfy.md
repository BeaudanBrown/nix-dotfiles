# Tailnet-only ntfy (NAS)

## Scope

NAS hosts `https://ntfy.bepis.lol` for Element X Android UnifiedPush and one
custom notification topic, `test`. Implementation lives in
`modules/hosted-services/ntfy/nas.nix`, selected by `generated/imports/nas.nix`.
No harness/bridge changes, automated alerts, public ntfy ingress, builds or
activation are part of this change. Runtime/phone acceptance remains operator-owned.

Validation on 2026-10-09: NAS system derivation evaluation, focused assertions
for ACLs/loopback binding/tailnet registration/no public DDNS/Synapse allowlist,
LSP diagnostics and diff whitespace checks passed. Evaluated ntfy version is
2.26.0. No secret provisioning, build, activation or live phone tests were run.

The existing `hostedServices` helper supplies tailnet DNS, DNS-01 ACME and Nginx
HTTPS. The backend listens only on an allocated loopback port; no additional
firewall port or public DDNS registration is added. Nginx supports WebSockets
and disables response buffering for streaming subscriptions. See
[tailscale-proxy.md](./tailscale-proxy.md) for the shared TLS ingress boundary.
Tailnet ACLs must permit the phone to reach NAS TCP/443.

## Authentication and persistence

- `auth-default-access = deny-all`; signup and topic reservations are disabled.
- SOPS provides `NTFY_AUTH_USERS` with one provisioned non-admin user, `phone`.
- `phone` has read-only access to `up*` UnifiedPush topics and read/write access
  to `test`, but no access to other topics.
- Anonymous clients have write-only access to `up*`, required by UnifiedPush
  application servers. They cannot subscribe or access `test`. Any permitted
  tailnet client knowing a generated push topic can publish to it; tailnet-only
  ingress is not a replacement for topic authorization.
- The NixOS ntfy module persists the auth database and message cache under
  `/var/lib/ntfy-sh`. Messages are cached for 12 hours; attachments are disabled.
- No Firebase key or upstream ntfy.sh forwarding is configured. Custom message
  payloads are visible to the server and may be stored in the cache: do not send
  passwords or other sensitive data. HTTPS is not end-to-end encryption.
- Removing a provisioned user from `NTFY_AUTH_USERS` deletes that user at the next
  ntfy restart. Change the configured hash to rotate the password, then update
  the saved phone credentials. Do not manage this account separately via CLI.

### Synapse private-address exception

Contrary to the initial plan, tailnet-only delivery needs a small Synapse change:
its HTTP pusher uses the blocklisted HTTP client and the default blocklist includes
`100.64.0.0/10`. This module adds only NAS's tailnet IPv4 `/32` to
`ip_range_whitelist`, retaining the default blocklist. It is an **IP-wide**
exception, not a hostname/path/port restriction: Synapse's affected outbound
clients can reach other services on that address too. Do not widen it to the
whole tailnet or disable the blocklist. Existing private runtime extra settings
were not inspected; ensure they do not override this setting at deployment.

Element X's diagnostic loopback sends directly from the phone to the push gateway;
real message notifications are sent by Synapse. Both the phone and Synapse must
resolve/reach the tailnet hostname. A successful loopback alone does not prove
Synapse delivery works. External homeservers without tailnet access cannot use
this endpoint for their pushers.

## Operator-owned secret setup (before deployment)

Choose a strong unique password and save it in your password manager. Generate
its bcrypt hash locally using ntfy's interactive command (do not use an online
hash generator):

```sh
nix shell nixpkgs#ntfy-sh -c ntfy user hash
```

The agent does not run this command, see the password/hash, or inspect private
secret files. Add the following structure to private `secrets/nas.yaml`:

```yaml
ntfy:
  auth-env: |
    NTFY_AUTH_USERS='phone:REPLACE_WITH_BCRYPT_HASH:user'
```

The placeholder is not a usable hash. Preserve all `$` characters from the hash;
the single quotes belong in the environment file. The plaintext password does
not go into the environment file or the Nix store. The secret is root-owned,
mode `0400`; changes restart `ntfy-sh.service`.

Operator command:

```sh
ssh nas 'cd /home/beau/sops-secrets && sops secrets/nas.yaml'
```

Commit/push the private secret change, then update only its input here:

```sh
nix flake update sopsSecrets
```

No new bot token, Matrix account, or certificate secret is required. Existing
NAS Cloudflare ACME credentials are reused. See [secrets.md](./secrets.md).

## Phone setup (after NAS deployment)

1. Keep Tailscale connected. Confirm `https://ntfy.bepis.lol` loads with a valid
   HTTPS certificate; never disable certificate verification.
2. Install the ntfy Android app, preferably its F-Droid build for a Firebase-free
   distributor. The Play build also uses direct connections for self-hosted servers.
3. In ntfy, use **Settings → Manage Users → Add New User** to enter
   `https://ntfy.bepis.lol` and the `phone` username/password.
   Select this URL as the **UnifiedPush server** in ntfy's settings;
   adding a custom subscription alone does not select the distributor server.
4. Allow ntfy notifications, background data and unrestricted battery usage.
   Keep its instant-delivery/background subscription service enabled. Tailscale
   must also remain able to run in the background.
5. Subscribe to `test` on this server. Publish a test message using ntfy's app,
   or from a tailnet-connected terminal (curl prompts for the password):

   ```sh
   curl --fail-with-body --user phone \
     --data 'ntfy custom notification test' https://ntfy.bepis.lol/test
   ```

6. Select ntfy/UnifiedPush in Element X's notification push-provider settings.
   Element X should create its own generated `up...` subscription; do not invent
   that topic manually. Verify its selected provider is no longer Firebase.
7. Rerun Element X's notification tests, then send a real Matrix message from
   another account/device while the phone is locked. Test both Wi-Fi and mobile.

## Deployment acceptance and rollback

Evaluation-only checks before the operator's build:

```sh
nix eval --json .#nixosConfigurations.nas.config.services.ntfy-sh.settings
nix eval --raw .#nixosConfigurations.nas.config.system.build.toplevel.drvPath
```

After secret provisioning, rebuild/deploy NAS using the normal workflow. Check:

- `systemctl status ntfy-sh.service` and its journal; no secret material in logs.
- HTTPS works from the tailnet. From an independent public connection, the ntfy
  vhost is unavailable even when forcing SNI/Host to this name on NAS's WAN IP.
- Anonymous access to `/test/json?poll=1` and publishing to `/test` returns 401/403.
- Authenticated `phone` access to other custom topics is denied.
- Anonymous reading of an actual generated `up...` topic is denied; legitimate
  anonymous UnifiedPush delivery is accepted. Never disclose its endpoint.
- Both Element X loopback and real Synapse notifications pass, including locked
  screen delivery and recovery after a network change/service restart.
- Other NAS public/private websites and existing Firebase pushers still work.

Do not claim live acceptance from evaluation alone. Check DNS from NAS as well
as the phone; if Synapse cannot resolve this hostname, diagnose the existing
split-DNS path rather than exposing ntfy publicly.

For rollback, first select Firebase again in Element X, then remove the ntfy
module/import and deploy NAS. This also removes the Synapse `/32` exception.
Retain the database unless explicitly choosing to erase it; clearing data loses
cached messages/accounts. Add separate publisher credentials and narrow topic
ACLs before introducing automated alerts; do not reuse the phone password in
system scripts.

## Sources

- [ntfy authentication and UnifiedPush ACLs](https://docs.ntfy.sh/config/)
- [ntfy Android and instant delivery](https://docs.ntfy.sh/subscribe/phone/)
- [Synapse configuration](https://element-hq.github.io/synapse/latest/usage/configuration/config_documentation.html#ip_range_whitelist)
- [Synapse HTTP pusher](https://github.com/element-hq/synapse/blob/develop/synapse/push/httppusher.py)
- [Element X loopback implementation](https://github.com/element-hq/element-x-android/blob/develop/libraries/push/impl/src/main/kotlin/io/element/android/libraries/push/impl/test/TestPush.kt)
