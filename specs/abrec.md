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

1. Push agent-workshop's `abrec` branch and merge it into `main`.
2. Set `inputs.agent-workshop.url` in `flake.nix` to that commit and run
   `nix flake lock`. Until then, nas fails to evaluate on this branch because
   the pinned agent-workshop has no `nixosModules.abrec`.
3. Rebuild nas.
4. Check `systemctl status abrec`, both ACME certificates, and that
   `audiobooks.bepis.lol` resolves publicly while `abrec.bepis.lol` resolves
   only on the tailnet.
5. Upload a book from the admin site, then on an iPhone check: following by
   the book page's link, chapter order, continuing to the next chapter while
   locked, the sleep timer, and how the library feed's seasons look.

Validation so far: evaluation only. With
`--override-input agent-workshop path:<abrec worktree>`, nas's
`system.build.toplevel.drvPath` evaluates; the admin vhost listens only on the
tailnet IP, ACME covers both domains, and DDNS covers only the public domain.
