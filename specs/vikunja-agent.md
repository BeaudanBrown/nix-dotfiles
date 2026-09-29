# Vikunja on NAS and on-demand Pi tools

## Implemented ownership

- `modules/hosted-services/vikunja/nas.nix`: Vikunja using the already-pinned
  `pkgs.unstable.vikunja` (2.6.0 at implementation), SQLite, allocated loopback port,
  and **tailnet-only** HTTPS at **https://todo.bepis.lol**. Existing ingress owns DNS
  and ACME. No new public DNS entry is requested for this application.
- `modules/hosted-services/vikunja/agent/`: shared client, typed Pi extension,
  project initializer and offline tests. Owned here, not copied into pi-harness;
  Home Manager installs it at `~/.local/share/vikunja-agent` on NAS and GRILL.
- `agent-host.nix` creates `~/documents/projects/todo-agent` with instructions and
  a regular project-local extension entrypoint on first activation. No global
  extension or mutable npm installation. Project data stays in Vikunja.
- `modules/cli/pi-harness/nas.nix`: a separate NAS managed-session relay using
  `@pi-nas:matrix.bepis.lol`. It does not extend the existing NAS chat assistant.
- NAS and GRILL share `modules/cli/tmux/shared-server.nix`, preserving the existing
  independently owned tmux server/update guard design. NAS gains the same client
  wrapper and shared-user NoNewPrivileges policy as GRILL.

**No Nix evaluation, build, rebuild, activation, live API calls, room creation or
secret access was performed.** The import lists were updated directly because their
normal generator invokes Nix evaluation, which the operator prohibited. Stage the
new module files deliberately before any future regeneration or Git-flake deployment.
Existing unrelated `flake.lock` and tailscale-proxy edits were left alone.

## Tool surface and behavior

14 tools provide status; paginated project/task/label/comment search and reads;
creation and partial editing of all four resources; immediate deletion; task
relations; and additive/removal label assignment. Task edits include completion,
priority, progress, project move and due/start/end dates. Project edits support
nesting, identifiers and archiving. Subtask and blocking relations work across
accessible projects. Repeated tool calls support bulk work, but are not a transaction.

No extra confirmation prompts, confirmation codes or delete preparation are
required. Deleting a project also deletes its descendants and tasks. Account ACLs,
input validation and stale-read checks are not approval gates. Unknown IDs or
ambiguous destinations must be resolved, not guessed.

No scheduled agents, proactive messages, webhooks, autonomous task execution or
GitHub/aloop replacement. No account/sharing administration, attachment tools, saved
filter CRUD, recurrence configuration or CalDAV tools in this first slice; these
can be handled in the UI where enabled. Native comments/attachments remain enabled;
public link sharing, CalDAV, webhooks and email reminders are disabled.

### API contract and concurrency

The client targets **v2.6.0**, not the development demo:

- [Resource routes](https://github.com/go-vikunja/vikunja/tree/v2.6.0/pkg/routes/api/v2)
  use `/api/v2`, POST create, PATCH edit, DELETE remove, numeric IDs, and list
  envelopes containing `items`, `page`, `per_page`, `total`, `total_pages`.
- Lists return 20 items per request. Responses are limited to 1 MiB; tool output
  is limited to 48 KB. Oversized reads return no usable edit revision.
- [Rich-text contract](https://github.com/go-vikunja/vikunja/blob/v2.6.0/pkg/routes/api/v2/richtext.go):
  GET/POST use `format=markdown`; PATCH strips query parameters and instead needs
  `X-Vikunja-Format`. Only rich-text edits request Markdown on PATCH. Other edits
  retain HTML mode, preventing the internal GET/PUT from stripping unrelated HTML
  formatting. Editing rich text through Markdown can itself lose HTML-only formatting.
- Updates re-read and compare a fingerprint with `vikunja_get`'s revision, then
  send a narrow merge-patch and forward the ETag if present. **This is not atomic
  cross-client optimistic locking:** AutoPatch does GET then PUT, project GET has
  no ETag, and DELETE/relation routes do not promise conditional mutation checks.
  Avoid simultaneous edits of the same resource. The earlier research's broad
  conditional-write recommendation must not be read as a transactional guarantee.
- Fixed HTTPS origin, no redirects, 30-second request timeout, runtime token reads
  for rotation, bounded/sanitized errors and no automatic mutation retries.
  An uncertain write outcome requires inspection before retrying.

## Secrets to populate (operator only)

Never paste credentials into Matrix, project files or model context. All declarations
already reference module-specific SOPS files and use mode `0400`.

| Private file | YAML/SOPS key | Exact value |
| --- | --- | --- |
| `secrets/nas.yaml` | `vikunja/service-env` | Multiline env-file string containing `VIKUNJA_SERVICE_SECRET=<stable random 64-character hex value>` |
| `secrets/nas.yaml` | `vikunja/api-token` | Raw NAS task-account API token, no `Bearer` prefix |
| `secrets/nas.yaml` | `pi/matrix-nas-env` | Env-file string containing only `PI_MATRIX_ACCESS_TOKEN=<token for @pi-nas:matrix.bepis.lol>` |
| `secrets/grill.yaml` | `vikunja/api-token` | Raw token for the restricted GRILL task account |
| `secrets/grill.yaml` | `vikunja/full-api-token` | Raw token for a separate full-access GRILL task account |

Example structure (values are placeholders, not usable credentials):

```yaml
# nas.yaml
vikunja:
  service-env: |
    VIKUNJA_SERVICE_SECRET=<random-stable-secret>
  api-token: UNPROVISIONED
pi:
  matrix-nas-env: |
    PI_MATRIX_ACCESS_TOKEN=<pi-nas-matrix-token>
```

Preserve other keys under existing `vikunja`/`pi` mappings. For first deployment,
API tokens cannot be issued until Vikunja is running: populate API-token entries
with literal `UNPROVISIONED` temporarily, then replace them after account setup.
Tools make no startup requests and will fail authentication if used prematurely.
If full GRILL access is not provisioned yet, its token can remain `UNPROVISIONED`;
never reuse the restricted credential and call it full access.

Edit yourself:

```sh
ssh nas 'cd /home/beau/sops-secrets && sops secrets/nas.yaml'
ssh nas 'cd /home/beau/sops-secrets && sops secrets/grill.yaml'
```

Generate the service secret yourself with a cryptographic generator (for example
`openssl rand -hex 32`), and keep it stable across restarts/restores. Version 2.6
uses **VIKUNJA_SERVICE_SECRET**, not the deprecated JWTSECRET spelling.
Create the distinct `pi-nas` bot account through your normal Synapse administration
workflow and obtain its Matrix access token. Do not substitute the existing owner
chat-assistant token or GRILL bot token. Use existing recipient/key maintenance
commands only if the NAS/GRILL recipients need changing; see [secrets.md](./secrets.md).
Commit/push the private changes yourself and update only `sopsSecrets` in dotfiles
when ready. Neither action has been performed here.

## Manual rollout (not executed)

1. Review the combined dirty worktree and stage/commit this implementation's files
   intentionally. Provision the real service secret and Matrix bot token, with API
   token placeholders as above. Validate/evaluate and build only when you decide to;
   no assertion of NixOS evaluability is made by the offline tests.
2. Plan a NAS tmux maintenance window. The shared-server wrapper cannot adopt a
   legacy live tmux server. Save/finish NAS sessions first. A guarded relay rollout
   may intentionally refuse an existing foreign server. Do not bypass its guard
   or kill live sessions to force deployment. See [tooling.md](./tooling.md).
3. On your chosen deployment date, activate NAS and GRILL yourself, e.g.
   `sudo nixos-rebuild switch --flake .#nas` on NAS and the corresponding `.#grill`
   on GRILL, from the reviewed checkout. A planned NAS reboot may be needed for
   fresh shared-server ownership; only do this after saving other NAS work.
4. Check tailnet DNS/TLS and `vikunja.service`. Verify the HTTPS application is
   unreachable off-tailnet, including its public NAS address with this SNI. The
   DNS name/certificate is not a secret; tailnet ingress is the access boundary.
5. With public registration disabled, bootstrap accounts through the packaged CLI.
   Use a transient unit with the same DynamicUser/StateDirectory so systemd exposes
   the private state directory to the CLI (plain `sudo -u vikunja` cannot traverse
   `/var/lib/private`):

   ```sh
   sudo systemd-run --wait --pty --collect --unit=vikunja-account-setup \
     -p DynamicUser=yes -p User=vikunja -p StateDirectory=vikunja \
     /run/current-system/sw/bin/vikunja user create --username beau --email <your-email>
   ```

   The CLI prompts for the password; do not put it on the command line. It reads
   `/etc/vikunja/config.yaml` and uses the same SQLite path. Repeat for distinct
   `todo-nas`, `todo-grill`, and `todo-grill-full` accounts with valid email addresses
   you control. Do not grant instance administration. CLI user creation does not
   need the service signing secret; don't print/source the service env file.
6. Create the desired Life, Software and Inbox projects in the UI. Share each
   applicable root with `todo-nas` and `todo-grill-full` at **Admin project** level
   if they must reparent/delete projects. Share only explicitly selected software
   projects with `todo-grill` (Read/Write, or project Admin if deletion/reparenting
   is desired). Verify nested inheritance and that Life is inaccessible to the
   restricted account. Full means access to deliberately shared projects, **not**
   an instance-wide administrator bypass. Newly created root projects may need
   manual sharing back to you and the other accounts.
7. Log in as each task account and create expiring API tokens. Grant the API actions
   needed for projects, tasks (including listing, labels and relations), labels and
   task comments: read/list/create/update/delete. PATCH may require both read and
   update because it internally reads then writes. Consult the instance's v2 API
   docs and token-scope UI; do not enable unrelated administration, sharing, webhook
   or credential-management actions. Record expiries and replace the corresponding
   SOPS values. Activate the updated secrets yourself. The tools reread token files
   on every call, so token rotation needs no Pi restart.
8. NAS uses the primary user's existing Pi model login/configuration, as its current
   assistant does. If needed, perform `pi /login` interactively yourself. Use a
   normal hosted model, not the local profile that restricts project tools.
9. After the NAS coordinator is available, ask it to start a conversation named
   **todo** for the **existing** workspace `todo-agent` under `projects`. Its room
   link is your primary interface. Keep membership to yourself and the bot; all
   joined participants have managed-session authority. Room creation is deliberately
   an operator action; no room ID or bot password is guessed by activation.

## GRILL opt-in and full access

The default `~/documents/projects/todo-agent` workspace on GRILL uses its restricted
account. Other existing coding workspaces opt in with:

```sh
vikunja-agent-init ~/documents/projects/my-project --project-id 123
```

Replace `123` with an actual accessible project ID. This binds default list/create
operations, not an ACL: server account sharing is the actual application boundary.
The initializer writes only its marked `.pi/extensions/vikunja.ts` and refuses an
unowned entrypoint or symlinked project configuration. It never overwrites AGENTS.md.
Reload/restart the project session to load the new entrypoint.

For an explicitly full-access GRILL conversation, create a separate workspace:

```sh
vikunja-agent-init ~/documents/projects/todo-full --profile full
```

Then start a managed conversation for `todo-full`. Copy/adapt the task instructions
from `todo-agent/AGENTS.md` if desired. Full and default profile selection is fixed
in the operator-written entrypoint, not exposed as a model tool argument. Both
credentials are readable by the same trusted Unix user: this is **not an OS sandbox**.
Do not let an agent change profiles to bypass a permission failure.

## Backup and restore

Backup destination/retention remains an operator deployment choice. No timer or
unapproved destination is configured. Before important use or upgrades, stop
`vikunja.service` in a maintenance window, archive the **contents of the resolved
`/var/lib/vikunja` directory** (SQLite database, any journal/WAL files, attachments),
then restart the service even if the backup command failed. Use a root-only archive
on a separate backup destination, and include an independent backup of your SOPS
secrets through your normal private-secret backup process. Avoid copying only a
live SQLite main file; it can omit committed WAL data. Do not follow attachment
symlinks when archiving. Keep the deployment's Vikunja version with the backup.

For restore, stop the service, preserve the current state separately, restore the
archive into the resolved state directory on the same Vikunja version, restore
appropriate ownership for the unit, and start it with the original service secret.
Verify login, representative tasks/relations, comments and attachment downloads.
Test this on a disposable instance before relying on it. **Live backup/restore is
not verified.** A NixOS generation rollback does not roll back database migrations.

## Verification and live acceptance

Offline checks use the already-installed SDK; no dependency download or Nix call:

```sh
PI_SDK_ROOT=/path/to/installed/pi-coding-agent \
  bash modules/hosted-services/vikunja/agent/check.sh
```

Implementation checks passed: **20 Node tests + 6 Python tests** and strict TypeScript
checking against both the installed Pi **0.85.0** SDK and the available **0.84.4**
SDK. Nix source syntax parsing (`nix-instantiate --parse`, not evaluation), shell
syntax, whitespace, and byte-for-byte preservation of the extracted shared tmux
server module also passed. No builds or Nix evaluation were run. Workspace LSP
reported missing ambient SDK/Node declarations; the explicit SDK typechecks passed.

The suite typechecks the extension/client against that SDK, tests mocked HTTP
routes, headers, errors, pagination, direct deletes, conflict prechecks and bounds,
checks tool schemas/no confirmation or scheduling hooks, and exercises initializer
profile/binding and file-ownership behavior. Workspace LSP may lack SDK dependencies;
this explicit SDK typecheck is authoritative for these files.

After deployment, verify in the NAS room: list projects, create a disposable nested
project and task, edit dates/text, comment, label, add a subtask/blocker, complete,
and directly delete disposable data without further confirmation. Verify a stale
edit fails and that unrelated HTML formatting survives a non-text edit. Exercise
restricted and full GRILL profiles, restart/resume/reload, token rotation, pagination,
and the tailnet-only boundary. All live checks, API scope compatibility, NixOS
activation and backup/restore remain outstanding until you run them.

See [planning decisions](./vikunja-agent-plan.md), [secrets](./secrets.md),
[modules](./modules.md) and [tooling](./tooling.md).
