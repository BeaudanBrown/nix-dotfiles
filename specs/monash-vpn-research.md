# Monash S-drive VPN routing investigation

## Public guidance

Monash's [S-drive mapping guide](https://www.monash.edu/esolutions/data-storage/map-s-drive) documents `\\ad.monash.edu\shared\` and requires VPN access off campus. Searches of Monash's public guidance did not locate a supported server-subnet allowlist or split-tunnel route list. This is not proof that no such list exists; ask eSolutions for supported routing requirements.

## Live observations on t480

Inspected with the Monash VPN connected. No credentials or private secrets were read. A metadata-only `stat` of `~/s` triggered its existing autofs mount; no share contents were read. No network configuration was changed.

- VPN supplied a default route through `tun0`, plus DNS host routes to `130.194.1.99` and `130.194.7.99`; no file-service-specific routes were present.
- REDCap resolved to `130.194.16.188` on and off VPN. TLS stalled on the VPN path; the user tested a temporary normal-gateway `/32` exception and obtained HTTP 200. That exception remained installed during this inspection. The underlying VPN-path failure is not diagnosed.
- `/proc/fs/cifs/dfscache` demonstrated the referral chain:
  `ad.monash.edu/shared` → `FILE-DFS01-V01.AD.MONASH.EDU/shared` → `narvi-1.ad.monash.edu/sdata17/Epi-Dementia`.
- `findmnt -rn -t cifs -o TARGET,SOURCE` confirmed the mount at `/mnt/monash-shared`.
- `ss -tn '( dport = :445 )'` showed established connections from VPN address `10.44.0.74` to `130.194.19.76`, `130.194.25.0`, and `172.16.20.135`.

IPv4 DNS observations from `resolvectl query -4`:

| Name | Observed addresses |
| --- | --- |
| `ad.monash.edu` | `130.194.19.{45,46,47,75,76,77}`, `10.27.192.{102,123}`, `10.32.160.59`, `10.32.161.95`, `10.30.96.{205,221}` |
| `FILE-DFS01-V01.ad.monash.edu` | `130.194.25.0` |
| `FILE-DFS02-V02.ad.monash.edu` | `130.194.25.64` |
| `FILE-DFS03-V01.ad.monash.edu` | `130.194.25.47` |
| `FILE-DFS04-V02.ad.monash.edu` | `130.194.25.85` |
| `FILE-DFS05-MUI.ad.monash.edu` | `172.24.139.8` |
| `narvi-1.ad.monash.edu` | `172.16.20.135` |

`ad.monash.edu` also returned IPv6 answers; the current VPN profile disables IPv6. Any future dual-stack policy needs separate validation.

## Conclusions

These are observed endpoints, not an authoritative subnet inventory. Do not infer `/24` or wider network ownership or future failover coverage from these addresses. Routing `130.194.0.0/16` through the VPN would include REDCap and would not cover the private-address SMB servers.

A static `/32` allowlist could support a controlled trial but would need to include DNS, namespace servers, all DFS alternatives, and storage targets; it is not guaranteed to survive DNS changes, failover, or additional shares. Disabling the VPN default route alone would break file-service routing.

Prefer supported subnet requirements from Monash eSolutions. If unavailable, network-namespace isolation of VPN plus CIFS is a stronger separation boundary than maintaining endpoint guesses, but needs careful authentication, DNS, mount visibility, and lifecycle design. DNS-driven routing alone does not guarantee coverage of future DFS referrals.
