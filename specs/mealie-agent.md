# Mealie upgrade and GRILL recipe agent

## Ownership

- `modules/services/mealie/nas.nix`: official NixOS Mealie module, now selecting
  `pkgs.unstable.mealie`. At the checked unstable input
  `6774f7bc253789b113a4f39285dc0fa100abeacc`, this is **3.22.0** (previously 3.16.0).
  SQLite, state directory, loopback, allocated port, timezone and HTTPS URL are unchanged.
- `modules/services/mealie/grill.nix`: Node 24 and host-owned runtime configuration
  for the recipe agent; SOPS token owned by the primary user, mode 0400.
- `~/documents/projects/mealie-agent`: separate local Git project with the API client,
  typed Pi tools, tests, agent instructions and its own development flake. Recipe data
  lives in Mealie, not this project or the dotfiles repository. The project is not a
  dotfiles flake input, globally loaded extension, or automatically published repository.
- Existing GRILL pi-harness coordinator/managed sessions: room lifecycle and model
  credentials. No new bot, NAS chat workspace or pi-harness source changes.

This first version covers recipe import, creation from pasted content, search/read,
metadata/ingredient/instruction edits (including append/remove), metric calculation,
tag/category creation and assignment, and confirmed recipe deletion. No meal planning,
shopping lists or decision-model integration. Routine imports/edits need no extra
approval. Bulk operations require conversational confirmation. Deletion requires a
short-lived exact user slash command, not a model-supplied confirmation boolean.

Agent instructions require cleanup of ingredient names, source/original-text retention,
explicit regional cup/spoon conventions, questions for ambiguity and no guessed density
conversion. A metric calculator supplies arithmetic; model compliance needs live testing.

## Manual rollout (operator only)

**No builds or activation were performed by the implementation agent.** The worktree
already contains unrelated staged/unstaged changes: review what you will deploy. Commit
or deliberately include the new Mealie files before relying on a Git-source flake; do
not indiscriminately stage other work. The generated GRILL import list must include
`modules/services/mealie/grill.nix`.

### 1. Upgrade NAS

From this dotfiles checkout, after reviewing the combined host configuration:

```sh
just deploy nas
```

This builds and switches NAS; it is a user-run command, not part of agent validation.
Alternatively activate from an up-to-date NAS checkout with
`sudo nixos-rebuild switch --flake .#nas`. Verify `mealie.service`, login and the
application's reported version. The existing upstream unit runs database initialization
before starting. No database migration project, PostgreSQL switch or backup automation
was added. A system-generation rollback alone is not guaranteed to undo database changes.

### 2. Create the integration identity

Visit `https://meals.bepis.lol/admin/manage/users` as an administrator:

- Create `recipe-agent` in your **existing group and household**.
- Enable **Organize group data** (needed for foods, units, tags and categories).
- Leave **Administrator**, **Manage group** and **Invite** disabled.
- Log in as `recipe-agent`, visit `/user/profile/api-tokens`, create its API token and
  note its expiry. Never send it through Matrix.

Mealie 3.22 allows non-admin deletion only for recipes owned by that account. Existing
recipes may also be locked against edits. Do not broaden privileges to bypass this:
manage those cases as the owner or explicitly adjust the individual recipe's edit policy.

### 3. Provision the GRILL secret

Run yourself:

```sh
ssh nas 'cd /home/beau/sops-secrets && sops secrets/grill.yaml'
```

Add the nested key `mealie.api-token` (SOPS path `mealie/api-token`) with the **raw token**,
not an environment-file assignment and not a `Bearer` prefix. Commit and push the
private repo change yourself. Then, from dotfiles:

```sh
nix flake update sopsSecrets
```

Only that input needs updating; do not update all fleet inputs. GRILL must be an allowed
recipient of `secrets/grill.yaml`. If recipients need regenerating, use the existing
`just gen-sops-yaml` and `just update-sops` workflow yourself. Agents must never inspect
or operate on the private secrets repo.

The token is rendered at `/run/secrets/mealie/api-token`. Home Manager writes only its
path and the HTTPS origin to `~/.config/mealie-agent/config.json`. The client reads the
token internally on each request. Do not put it in project settings or global environment.

### 4. Activate GRILL and start the conversation

On GRILL, from the reviewed dotfiles checkout:

```sh
sudo nixos-rebuild switch --flake .#grill
cd ~/documents/projects/mealie-agent
node scripts/status.ts
```

The status command is authenticated and read-only; it returns group metadata, not secrets.
There is no new agent daemon to restart and no need to restart the Matrix relay merely
for this project. Existing tmux/relay maintenance restrictions still apply if unrelated
pending changes require them; see [tooling.md](./tooling.md).

In the existing GRILL coordinator, request a conversation named **recipes** for the
**existing** workspace `mealie-agent` under the `projects` root. No room was created by
implementation. The coordinator returns its room link. Initially keep membership to
yourself and the bot; every joined participant has equal managed-session authority.
Select a normal hosted model: the current local-model managed profile restricts custom
engineering tools and is not the supported recipe-agent profile.

No npm install is required for ordinary use. Pi loads `.pi/extensions/mealie.ts` and
supplies its SDK/TypeBox peers. The project is not automatically copied to another host.
It is unavailable while GRILL is off; future host placement is a separate enhancement.

### 5. Live acceptance

- Confirm Mealie status and group in the dedicated room.
- Import one trusted public recipe URL and verify the saved link, source, ingredient
  cleanup, metric quantities and oven setting. Ambiguous source measures must cause a
  specific question, not a guessed conversion.
- Create a small test recipe from pasted content; edit an ingredient/step and assign
  a tag/category. Check that unrelated content and original ingredient text remain.
- Prepare deletion of that agent-owned test recipe. Verify it remains until **you**
  send the exact returned `/mealie-confirm-delete` command; verify removal afterward.
- Resume/reset the conversation using normal coordinator controls and confirm tools
  reload. Pending deletion codes are intentionally lost on reload/reset.

## Security and limits

The existing GRILL agent has host-user authority: these tools are not an OS sandbox.
Confirmation is a workflow boundary. Other trusted programs under that user can read
its secret. Mealie provides the account permissions; keep its token non-admin.

Authenticated API requests refuse redirects, use a fixed configured HTTPS origin,
limit response sizes and never automatically retry mutations. Recipe import validates
the initial public HTTPS destination, but **is not a complete SSRF boundary** because
Mealie does its own DNS resolution and redirects. The newer 3.26 server HTTP hardening
is not present in this 3.22 target; use trusted recipe URLs.

Read-before-write fingerprints detect stale reads, not concurrent transactional writes.
Avoid simultaneous editing of the same recipe. Global organizer rename/deletion and
ingredient/step reordering are intentionally outside the initial tool surface.

## Verification

Offline client/extension tests and typechecking run in the dedicated project using
Node 24 and the existing harness SDK type links; see its README. Evaluation-only
checks in dotfiles verify the selected package, service unit, GRILL imports, public
configuration and secret ownership. No test reads a real token or writes live recipes.

Implementation checks on 2026-09-27 passed: 25 offline tests plus TypeScript checking
with both the existing harness Pi 0.84.4 SDK and installed Pi 0.85.0 SDK. NAS/GRILL
focused option/unit evaluation passed (3.22.0, loopback port 13436, SQLite, original
state directory, owner `beau`, mode 0400). The project's pinned development-shell
derivation evaluated without building. Workspace LSP diagnostics and whitespace checks
were clean. No real token, live Mealie request, build or activation was used.

Live account provisioning, deployment, actual model cleanup behaviour and the Matrix
round trip remain operator acceptance steps. Mock tests do not establish those results.

## References

- [Mealie 3.22 release](https://github.com/mealie-recipes/mealie/releases/tag/v3.22.0)
- [Official API documentation](https://mealie.io/documentation/getting-started/api-usage/)
- Project `docs/api-contract.md`: pinned route/schema sources and live checklist.
- [Secrets](./secrets.md), [modules](./modules.md), [tooling](./tooling.md).
