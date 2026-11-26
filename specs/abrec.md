# abrec on nas

abrec records and publishes read-aloud books as private podcast feeds. The
tool, its NixOS module and its design live in agent-workshop
(`tools/abrec/README.md`, `nixosModules.abrec`); this repository only
chooses where it runs.

## Wiring

- `hosts/nas/default.nix` imports `inputs.agent-workshop.nixosModules.abrec`.
- `modules/hosted-services/abrec/nas.nix` enables it with:
  - `abrec.bepis.lol`: admin site, `tailnet = true`, bound to nas's tailnet IP.
    It has no login; being on the tailnet is the only access control, and
    deletion is permanent.
  - `audiobooks.bepis.lol`: public static listener site and feeds under an
    unguessable secret path, with Cloudflare DDNS.
  - Both virtual hosts are owned by the abrec module (`doNginx = false`,
    `manageNginxListeners = true`); this module adds TLS and listen addresses.
- State is `/var/lib/abrec` on the `pool1/var` ZFS dataset. abrec makes no
  backups; masters exist only there.

Adding books and chapters needs no rebuild. On nas,
`sudo -u abrec abrec render /nix/store/…-abrec.json` (the path is in
`systemctl cat abrec`) rebuilds the public site by hand.

## First deployment

1. `inputs.agent-workshop` is pinned to the commit `7ddd89c` on agent-workshop's
   `abrec` branch, the first with `nixosModules.abrec`. Once that branch is merged
   into agent-workshop `main`, re-pin to the merged commit.
2. Rebuild nas.
3. Check `systemctl status abrec`, both ACME certificates, and that
   `audiobooks.bepis.lol` resolves publicly while `abrec.bepis.lol` resolves
   only on the tailnet.
4. Upload a book from the admin site, then on an iPhone check: following by
   the book page's link, chapter order, continuing to the next chapter while
   locked, the sleep timer, and how the library feed's seasons look.

Validation so far: evaluation only. With
`--override-input agent-workshop path:<abrec worktree>`, nas's
`system.build.toplevel.drvPath` evaluates; the admin vhost listens only on the
tailnet IP, ACME covers both domains, and DDNS covers only the public domain.
