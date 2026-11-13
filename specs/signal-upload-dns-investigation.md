# Signal upload and NAS DNS investigation

Investigated 2026-11-06 using read-only runtime inspection. Configuration changes were subsequently implemented with operator approval, as described below. No Nix evaluation, build, activation, restart or message send was performed; evaluation was explicitly prohibited for the implementation handoff.

## Implementation and rebuild handoff

Implemented in:

- `modules/services/matrix/nas.nix`: hash-pinned upstream patch applied in postPatch only to the recognized old source. Recognized fixed source skips the patch; unknown layouts fail with a review message. Existing postPatch is preserved. Remove the override once the locked package carries the fix.
- `modules/system/networking/nas.nix`: declaratively adopt the existing `Wired connection 2` runtime profile (same filename and UUID, interface enp7s0). Retain automatic IPv4/IPv6 addressing; ignore DHCP/RA DNS; use Cloudflare/Quad9 and a link-specific `~.` public route. More-specific global private routes take precedence. No other device's connection profile is changed.
- `modules/hosted-services/nas.nix`: existing `coredns.service` serves loopback only and has no tailnet readiness dependency. New `coredns-tailnet.service` retains the existing tailnet zones/blocklist and retries its own IP-readiness check indefinitely after failures. Headscale's advertised split routes, firewall rules, MagicDNS forwarding and the global `lan` search suffix are unchanged. Local private hosted zones now terminate at the local resolver rather than falling through to public upstreams.

The unknown MagicDNS-name SERVFAIL behavior remains an explicit limitation. This change avoids coupling public DNS startup to it; it does not fabricate NXDOMAIN during real MagicDNS failures. Short names remain supported as requested.

Validation: editor diagnostics reported no issues in the three edited Nix files. No Nix evaluator, build, live DNS change, service restart or fault-injection test was run. Runtime acceptance and package build compatibility remain unverified.

After the operator rebuilds/activates NAS:

1. Check `systemctl status coredns coredns-tailnet NetworkManager-ensure-profiles mautrix-signal`.
2. NetworkManager's ensure-profiles service reloads saved connections, but does not explicitly reapply an active connection. Inspect `resolvectl status enp7s0`; if it still shows old DNS, use `sudo nmcli device reapply enp7s0` from a session with recovery access. This is intended to apply DNS-only changes without taking the link down. If reapply fails, schedule a controlled reconnect/reboot rather than disconnecting a remote session blindly.
3. Confirm enp7s0 DNS is 1.1.1.1/9.9.9.9 with `~.`, and global private routes plus the `lan` search suffix still exist. Resolve `chat.signal.org`, `grill`, `grill.lan`, and a private hosted name on NAS; verify private hosted names and blocking from another tailnet device as well.
4. Send a small image to Signal Note to Self and check its receipt, not merely Matrix acknowledgement.
5. In a separate approved maintenance window, verify public DNS survives unavailable tailnet DNS, and tailnet DNS recovers when its IP arrives late. Do not perform a remote connectivity-disrupting test without an alternate access path.

No temporary resolvectl overrides were applied. If an operator previously applied temporary overrides, remove them only after confirming the declarative profile supplies the intended DNS.

## Attachment upload

NAS is running mautrix-signal 26.10. At 12:18:34 and 12:19:04 AEDT on November 6, Matrix-to-Signal attachment sends failed with `failed to decode upload attributes: unexpected response status 400`. The response included `X-Signal-Timestamp` and an empty body, identifying the rejection as Signal-side rather than Synapse/Nginx upload limits.

[Upstream PR #703](https://github.com/mautrix/signal/pull/703), merged November 4 at 22:28 UTC, describes this exact error: Signal-Server made `uploadLength` mandatory on `GET /v4/attachments/form/upload`. [Commit e2e994f](https://github.com/mautrix/signal/commit/e2e994f99f8dfffe5ad1cc88a2d36449639a609e) sends the encrypted attachment length including MAC.

Current package checks:

| Source | Version | Includes fix? |
| --- | --- | --- |
| [Upstream latest release](https://github.com/mautrix/signal/releases/tag/v0.2610.0) | v0.2610.0 / 26.10 | No |
| [NixOS stable nixos-26.05](https://github.com/NixOS/nixpkgs/blob/7dcdd87373d72e7a2173e4db02e20d3d7f495cfd/pkgs/by-name/ma/mautrix-signal/package.nix) | 26.10, no patches | No |
| [NixOS unstable](https://github.com/NixOS/nixpkgs/blob/1d060086d60cb76a40cf37109f979d88a5bd6396/pkgs/by-name/ma/mautrix-signal/package.nix) | 26.10, no patches | No |
| Nixpkgs master | 26.10, no patches | No |
| [Upstream main](https://github.com/mautrix/signal/compare/e2e994f99f8dfffe5ad1cc88a2d36449639a609e...main) | next development release, changelog labels 26.11 unreleased | Yes |

No newer published release or prerelease appeared in the GitHub releases API. Future 26.11 inclusion is expected from main ancestry, not a verified published package. Changing to unstable or merely updating the lock currently does not fix it. The current worktree's stable and unstable locks both reference c59305bab2065cfecc4944690d9eedbb56f3a9fa; runtime version was checked separately.

Recommended immediate fix: in `modules/services/matrix/nas.nix`, override `services.mautrix-signal.package`, preserving existing patches and adding a hash-pinned backport of e2e994f using `pkgs.fetchpatch`. Retain stable dependencies/libsignal rather than moving the whole package to main. This one-line source change does not change Go dependencies. Evaluate, then separately authorize a targeted build/activation and send a small image to Note to Self. Remove the override once the locked package demonstrably contains the fix. No patch hash or build compatibility was verified during this investigation.

## DNS evidence

Configuration sources: `modules/hosted-services/nas.nix`, `modules/hosted-services/server.nix`, `modules/system/networking/network.nix`, `modules/services/headscale/nas.nix`.

### Boot dependency failure (confirmed)

- NAS configures global resolved DNS as 127.0.0.55 (CoreDNS).
- One CoreDNS process owns both loopback and tailnet listeners. Its unit requires `tailscaled` and `wait-for-tailscale-ip`, and orders after Headscale.
- November 5, 18:24–18:25: Headscale repeatedly failed OIDC discovery because `auth.bepis.lol` could not resolve.
- 18:26:41: wait-for-tailscale-ip timed out; CoreDNS start failed with dependency result.
- 19:24:52: CoreDNS finally started; its loopback and tailnet listeners appeared at 19:24:53.
- Resolved repeatedly toggled UDP/TCP degraded mode for the unavailable loopback server before this startup.
- Signal logged lookup failures during the outage. No further `lookup chat.signal.org` entries were found after 19:25 in the available journal.

This creates a bootstrap dependency trap: public DNS depends on the tailnet becoming ready, while Headscale needs public DNS for OIDC discovery. `Restart=on-failure` on CoreDNS is not sufficient when its start job is rejected because a required unit failed.

`FallbackDNS` is not general failover for a configured-but-unavailable DNS server: [resolved.conf](https://www.freedesktop.org/software/systemd/man/256/resolved.conf.html) says it is used only when no other DNS server information is known. Runtime also has DHCP-provided DNS on enp7s0 (103.51.112.20 and 103.85.36.20), so not every public query necessarily traverses CoreDNS. This does not remove the observed boot failure.

### MagicDNS negative answers (confirmed, impact partly inferred)

Historical CoreDNS logs show repeated `chat.signal.org.lan` SERVFAIL responses. Tailscaled concurrently logged `dns: resolver: forward: no upstream resolvers set, returning SERVFAIL`.

Current probes reproduce the negative-response defect:

- `dig @127.0.0.55 chat.signal.org.lan A +time=2 +tries=1`: SERVFAIL.
- `dig @100.100.100.100 chat.signal.org.lan A +time=2 +tries=1`: SERVFAIL.
- `dig @100.100.100.100 definitely-missing-check.lan A +time=2 +tries=1`: SERVFAIL.
- `dig @100.100.100.100 grill.lan A`: NOERROR, 100.64.0.21.

The current non-route-only `lan` domain adds a search suffix. Failed public lookups can consequently generate `.lan` queries, aggravating failures through a resolver that cannot answer unknown names cleanly. This is not evidence that Signal's real public hostname is blocked. It also does not prove a forwarding loop: the actual logged Tailscale error is absence of upstream resolvers.

### Recommended robust DNS design

1. Remove all tailnet dependencies from NAS public DNS resolution. Configure deliberate, reachable public resolvers for public/default queries rather than depending on incidental DHCP DNS or FallbackDNS.
2. Keep split DNS explicit: route hosted private domains to a local resolver and route `~lan` to MagicDNS; do not send private zones to public fallback resolvers. Resolved chooses the most-specific route; use separate resolver scopes/links when assigning different DNS servers to different suffixes. Do not simply mix private and public servers in one global DNS list: they are not interchangeable.
3. Split loopback hosted-name DNS and tailnet/blocklist DNS into independently started units. Loopback DNS must start without Headscale/Tailscale or a tailnet IP; only the tailnet-serving unit should depend on the Tailscale IP. Make the latter recover automatically when readiness arrives after an initial failure. This avoids a tailnet bind/readiness failure taking down the local listener.
4. Prefer route-only `~lan`, requiring explicit `grill.lan` names instead of implicit short-name search. If short names are required, keep search deliberately and fix unknown-name responses. Give MagicDNS a valid negative-answer path (authoritative NXDOMAIN for unknown names inside its own zone), without falling back to public DNS for private `.lan` names or forwarding back into the same resolver chain. A zone-scoped CoreDNS fallback for SERVFAIL can be considered, but only after testing real MagicDNS unavailable vs genuinely absent names; blindly converting every failure to NXDOMAIN masks outages and negatively caches valid names.
5. Monitor public DNS, a known hosted name, a known MagicDNS name, and an unknown MagicDNS name separately. Add boot/late-tailnet acceptance checks: public DNS and Headscale OIDC discovery must work before tailscale0 exists; public DNS must survive tailnet service failure. Unknown MagicDNS names should return NXDOMAIN, not repeated SERVFAIL/timeouts.

Merely increasing startup timeouts, ordering Signal after CoreDNS, hardcoding Signal IPs, or adding more FallbackDNS servers does not remove the architectural failure.

Current public checks all succeeded: `dig @127.0.0.53`, `@127.0.0.55`, `@1.1.1.1`, and `@9.9.9.9 chat.signal.org A +time=2 +tries=1`; responses were NOERROR in 0–21 ms. `resolvectl query chat.signal.org` also succeeded. Historical boot failures were not re-triggered; no services were disrupted to reproduce them.

Reference: [CoreDNS forward behavior](https://coredns.io/plugins/forward/) distinguishes network errors from DNS response codes; `failover SERVFAIL` must be explicit when response-code failover is intended. It is not a substitute for separating public DNS from tailnet readiness.
