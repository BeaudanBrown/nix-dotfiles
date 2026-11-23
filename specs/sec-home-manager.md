# Agent Workshop sec in Home Manager

[The `main`-root module](../modules/cli/sec/main.nix) installs `sec` through
Home Manager for the primary user on `grill`, `laptop`, `nas`, and `t480`.
Hosts without the `main` root do not get it. It uses the existing Vaultwarden
endpoint (`https://pw.bepis.lol`), fleet `pkgs.bitwarden-cli`, and
`agent-tools-nixpkgs` SecretSpec pin. The existing SecretSpec provider, agent
mocks, and standalone CLI packages are unchanged.

The generated host import lists select the module by its `main.nix` filename;
no per-host import is needed. Future regeneration uses `just gen-imports <host>`
from a checkout with the module tracked (the generator ignores untracked files).

## Evaluate the integration in isolation

Run from the dotfiles checkout. The fixture evaluates the real Home Manager
bridge with synthetic users and uses public pins from the fleet lock. It does
not load the fleet flake or access the private SOPS input.

Use the fleet’s published Workshop revision, not the default GitHub branch:

```sh
workshop_rev=$(nix --extra-experimental-features nix-command eval --impure --raw --expr '
  let lock = builtins.fromJSON (builtins.readFile ./flake.lock);
  in lock.nodes.${lock.nodes.root.inputs.agent-workshop}.locked.rev')
nix --extra-experimental-features 'nix-command flakes fetch-tree' eval \
  "path:$PWD?dir=tests/sec-home-manager#result" \
  --override-input agent-workshop "github:BeaudanBrown/agent-workshop/$workshop_rev" \
  --no-write-lock-file --option allow-import-from-derivation false --json
```

To test a local Workshop edit instead, use `path:/absolute/path/to/worktree`
as the override. Use `path:` only with checkouts that contain no private files.
Do not write a fixture lock file for either override.

The fixture checks generated import membership against the fleet root assignments.
It evaluates the relevant imports from `grill` and `agent`, checking primary-user
installation on a `main` host, absence on a non-`main` host and from the system
package list, package pins, and the existing provider setting.

## Update the Workshop pin

The [fleet flake](../flake.nix) declares the published revision and the
[fleet lock](../flake.lock) records it. To upgrade, select a published revision
that exports `homeManagerModules.sec`, update only the `agent-workshop` input
(`nix flake update agent-workshop`), and rerun the isolated fixture. The
generated host imports need no change when only the revision changes.
