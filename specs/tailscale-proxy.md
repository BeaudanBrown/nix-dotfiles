# Always-on Tailscale HTTPS proxy (NAS and t480)

## Scope and status

NAS hosts an authenticated NaiveProxy-compatible sing-box inbound at
`proxy.bepis.lol:443`. Only t480's `tailscaled` uses the local HTTP proxy;
NAS's own Tailscale daemon and other hosts are unchanged. The Headscale login
server remains `https://hs.bepis.lol`.

This configuration was authored without Nix evaluation, builds, activation,
private-secret access, or live network tests, at the operator's request.
Syntax/static checks are not deployment validation. Validate both hosts before
activation, and deploy/test NAS before enabling the t480 client.

## Transport and NAS HTTPS ingress

- t480 coordination and DERP TCP connections use loopback HTTP CONNECT, then
  Naive over TLS/HTTP2 to NAS. QUIC is disabled; no second TUN interface exists.
- Direct peer UDP remains direct. When relayed, the proxy remains in the data
  path for the entire connection, not merely its setup.
- NAS's own Headscale/embedded DERP destination is routed through loopback
  port 443, avoiding a WAN hairpin. Other public HTTPS destinations (including
  other DERPs) are allowed; resolved private IPs and non-TCP/non-443 destinations
  are rejected. This does not force NAS DERP selection or alter its map.
- Nginx's stream layer owns public and tailnet TCP/443 without terminating
  TLS. SNI `proxy.bepis.lol` selects sing-box; other names select Nginx's own
  HTTPS backends. There is no HAProxy service.
- Nginx TLS listeners move to allocated loopback ports, behind PROXY protocol.
  Only connections originally addressed to NAS's tailnet IPv4 address may use
  the private backend. Public vhosts also listen there; tailnet-only vhosts do
  not listen on the public backend. Spoofing SNI or HTTP Host on a public
  connection cannot select a private vhost. HTTP port 80 retains its existing
  public/tailnet address restrictions.
- Client addresses are restored for websites with Nginx's real-IP module,
  trusting only the loopback PROXY-protocol sender. Raw TLS services use one
  shared loopback adapter that consumes the PROXY header and routes by SNI
  again. Their TLS is untouched, but they see a loopback peer address. Backend
  ports are not opened in the firewall.
- `hostedServices` continues to own Cloudflare DNS-only DDNS and DNS-01 ACME.
  The proxy sets `tlsPassthrough = true`, which defaults `doNginx` to false:
  an ordinary HTTP reverse proxy cannot carry this HTTP/2 CONNECT transport.
  Do not enable Cloudflare's orange-cloud proxy/tunnel for this hostname.
- The shared module `modules/services/nginx/tls-ingress.nix` is imported by
  `modules/hosted-services/server.nix`. It only changes listeners and allocates
  ingress ports while at least one passthrough entry exists. Removing the last
  registration restores native HTTPS listeners without changing application
  modules. Passthrough entries must be public and must not also request an
  HTTP vhost or managed Nginx listeners; an assertion enforces this boundary.
- `manageNginxListeners` defaults to `doNginx`. Jitsi explicitly sets it to true
  while retaining `doNginx = false`, so the shared module manages listeners but
  Jitsi still owns its vhost content. No Jitsi domain is hard-coded in the
  ingress or proxy modules. iDRAC's DNS-only, remote-host record remains opted
  out. Future externally managed HTTPS vhosts must register the same way.

The ingress change affects **all NAS HTTPS services**, not just Headscale.
Nginx has no dependency on sing-box or the proxy certificate, so a failed proxy
backend does not prevent ordinary HTTPS from starting. Plan a maintenance
window and a full Nginx restart when moving port 443 between the HTTP and stream
layers (in either direction); do not assume a graceful reload migrates existing
connections safely. Do not perform it using the new proxy as your only
administrative path.

## Package and runtime ownership

Both hosts use `pkgs.unstable.sing-box` from the existing shared unstable
overlay. `nixpkgsUnstable` is pinned to
`6774f7bc253789b113a4f39285dc0fa100abeacc` (sing-box 1.14.1), with Naive outbound
and Chromium/Cronet support. The main stable package set remains unchanged;
there is no separate proxy-specific nixpkgs input.

Updating this shared input also changes FreeCAD on t480, Docling Serve and
Open WebUI on NAS, OnePlus's Qualcomm daemons, and nixpkgs dependencies of the
llama-cpp, art-domain, OpenClaw and Fenix inputs. Validate affected consumers
before deploying; this is not a sing-box-only dependency update. Public
nixpkgs metadata was fetched with `nix flake prefetch` and used to update only
the unstable lock node, without evaluating host configurations or accessing
the private secrets input.

Both services run as `sing-box` with upstream TUN/ptrace/DAC capabilities
removed. Passwords are substituted into `/run/sing-box/config.json` via the
NixOS module's `_secret` support, not embedded in the Nix store. Secret changes
restart sing-box; the ACME certificate's group is `sing-box`, and renewal reloads
it. No new public plaintext listener is created.

The t480 loopback HTTP endpoint is unauthenticated, so other local processes can
use it. This assumes the existing single-user trusted-host model. It is not a
system-wide browser proxy. Headscale/Authentik browser login may still need a
separate browser proxy configuration when those destinations are blocked.

`HTTP_PROXY`/`HTTPS_PROXY` are scoped to `tailscaled`, and
`TS_FORCE_NOISE_443=true` prevents its HTTP/80 control-protocol fast path. This
is an internal Tailscale knob: recheck it when upgrading Tailscale. There is no
automatic direct fallback. A proxy outage can prevent coordination/DERP access
although existing direct peer connections may continue temporarily.

## Operator-owned secrets (not created by the agent)

In the private repository, put this structure in **both** `secrets/nas.yaml`
and `secrets/t480.yaml`, encrypted for each host's recipients:

```yaml
tailscale-proxy:
  password: REPLACE_WITH_THE_SAME_LONG_RANDOM_PASSWORD_IN_BOTH_FILES
```

The YAML value above is a documentation placeholder, not a usable credential.
Username `t480` is public configuration. Generate a strong unique password;
keep the two values identical. No other new secret is required. Existing NAS
`cloudflare/env` and `cloudflare/ddns_token` are reused by `hostedServices`.

If the t480 host-specific file/recipient rule does not exist yet, run
`just gen-sops-yaml` from this dotfiles repository first (operator only), then
edit the encrypted files:

```sh
ssh nas 'cd /home/beau/sops-secrets && sops secrets/nas.yaml'
ssh nas 'cd /home/beau/sops-secrets && sops secrets/t480.yaml'
```

Commit and push those changes in the private repository. If recipient keys
changed, use `just update-sops` as documented in [secrets.md](./secrets.md).
Then update **only** the `sopsSecrets` flake input in this repository:

```sh
nix flake update sopsSecrets
```

These are instructions for the operator; none were executed during this change.
Missing secrets intentionally fail provisioning rather than default to a known
password. Do not deploy the client before the remote endpoint is operational.

## Deployment acceptance (deferred; operator-run)

1. Check the encrypted files and recipient rules, update the secrets input, and
   validate NAS and t480 configurations before building either system.
2. Ensure `proxy.bepis.lol` has a DNS-only public record maintained by DDNS and
   the existing router's TCP/443 forwarding still reaches NAS. Remove stale
   AAAA records if IPv6 does not actually reach NAS. No new router port is needed.
3. Deploy NAS first during a maintenance window. Verify Nginx's stream layer
   owns 443, HTTPS/sing-box backends listen only on loopback, and the certificate is
   valid/readable. Test representative public sites, Jitsi, Headscale, private
   sites from the tailnet, and denial of private sites via public SNI/Host.
4. Deploy t480. Complete any Wi-Fi captive-portal login before testing. Check
   `tailscale status`, a fresh coordination map, `tailscale ping nas`, SSH, and
   tailnet DNS on both ordinary Wi-Fi and the affected restrictive network.
   Test a genuinely relayed connection as well as a direct one; ordinary HTTPS
   success is not proof the full control/DERP path works.
5. Verify other advertised DERP destinations can be reached through the proxy,
   and verify NAS's own Headscale path works without router hairpin support.
6. Test recovery after restarting sing-box, credential rotation, certificate
   renewal, and suspend/resume. Do not claim automatic fallback: it is absent.

For rollback, remove/disable t480's proxy module and activate that change first;
then remove NAS's proxy module/registration. With no other passthrough entry,
shared ingress automatically stops allocating ports and overriding listeners,
including Jitsi's. Other passthrough registrations, if any, keep it active.
Keeping t480's proxy variables while removing sing-box breaks control/relay
connectivity. Test both the enabled and last-registration-removed configurations
before deployment. Keep a hotspot or independent administrative connection
available.

The two generated import manifests were synchronized by a static insertion in
host-stem sort order: their usual generator runs `nix eval`, which was forbidden
for this task. Regeneration should retain these entries once files are tracked.

## Sources

- [Nginx TLS preread routing](https://nginx.org/en/docs/stream/ngx_stream_ssl_preread_module.html)
- [Nginx stream proxy and PROXY protocol](https://nginx.org/en/docs/stream/ngx_stream_proxy_module.html)
- [sing-box Naive inbound](https://sing-box.sagernet.org/configuration/inbound/naive/)
- [sing-box Naive outbound](https://sing-box.sagernet.org/configuration/outbound/naive/)
- [Pinned Naive-capable package](https://github.com/NixOS/nixpkgs/blob/6774f7bc253789b113a4f39285dc0fa100abeacc/pkgs/by-name/si/sing-box/package.nix)
- [Tailscale control proxy support](https://github.com/tailscale/tailscale/blob/v1.98.10/control/controlhttp/client.go)
- [Tailscale DERP proxy support](https://github.com/tailscale/tailscale/blob/v1.98.10/derp/derphttp/derphttp_client.go)
