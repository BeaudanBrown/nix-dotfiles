# dump.bepis.lol publishing

## Chat capability rollout handoff

- Harness revision: `99fd69601b51886c241d67d5b0d11a7fdb420dbf`, pinned in `flake.lock`. It must be pushed/made available at the configured GitHub source before a fresh NAS fetch. Local verification has the exact committed source cached; that alone does not establish remote availability.
- First make this dotfiles revision and its pinned harness source available on the deployment machine; then rebuild **NAS** using the normal host deployment procedure. No GRILL rebuild is required for NAS chat capabilities. GRILL remains an independent ordinary editor; rebuilding it later does not add chat-only tools to CLI sessions.
- The source is already on NAS and mounted on GRILL. Do **not** repeat the historical starter-transfer/rename instructions below or overwrite the existing project.
- NAS activation provides `pi-chat-workspace`, `pi-chat-model` and `pi-chat-transport`; the existing publisher remains separate. Workspace access is granted only to the configured Note to Self room. Downloads/file sending are enabled for every currently enabled assistant chat; the existing room allowlist is not widened.
- After activation, check those units and the model/transport operational logs. Test a read-only project question first, then a public PDF attachment from Matrix and Signal Note to Self. Verify the actual owner/Signal account and received bytes; Matrix acknowledgement is not downstream delivery proof.
- A real website edit/publication test requires a clearly requested disposable change. Confirm the published receipt and changed public URL; failure must leave the prior release serving. Do not repeat an uncertain publication or file send blindly—inspect status or issue a new explicit request as appropriate.
- Completed evidence: all 12 canonical harness checks; production packages; actual isolated download/decoder/workspace probes; 15 publisher tests; real Hugo publishing into disposable queue/release directories; full NAS and GRILL dry evaluation. No production source/queue/release, live chat delivery or host activation was changed during verification.


## Implemented design

The Hugo source project is `~/documents/projects/dump` on GRILL. NAS backs that exact directory through a GRILL-only NFS export of `/var/lib/dump-site/project`, stored on the existing `pool1/var` ZFS dataset mounted at `/var/lib`. The site is public and static. Roots map to URL paths, initially `/josh/`, not new domains. The publisher itself has no model, public upload handler or Matrix credentials. The module now also prepares a separate opt-in harness workspace executor and Note to Self binding for NAS chat editing; that executor does not receive model or Matrix credentials.

Infrastructure lives in `modules/hosted-services/dump/`:

- `nas.nix`: public DNS/ACME registration, owned Nginx vhost, shared TLS ingress integration, dedicated NFS export, publisher identity, timer and sandbox.
- `grill.nix`: dedicated systemd NFS automount and `dump-publish`/Hugo packages. The existing autofs `autoMaster` option is a non-merging string; this new mount deliberately does not redefine it. The project path is excluded from the enclosing `documents` Syncthing folder so Syncthing does not traverse the nested NFS mount.
- `package.nix`, `publish.py`: fixed host-owned CLI/protocol shared by GRILL and NAS.
- `test_publish.py`: executable protocol tests with a fake Hugo (not template/render tests).

The manifest entries in `generated/imports/{nas,grill}.nix` were synchronized by sorted insertion, preserving unrelated pending changes. The normal generator filters to Git-tracked modules; track the new module files before running `just gen-imports nas` / `just gen-imports grill` during operator deployment. No build or activation was performed by the implementation agent.

## Separate content project

The starter was created at `/home/beau/documents/projects/dump`, initially as an ordinary local directory. It has its own Git repository (no commits/remote), pinned tooling flake, layouts, styles, search, instructions, tests, reference syllabus and content. Its files are NOT stored in this dotfiles repository. Back up/transfer that directory separately.

The original syllabus was migrated into 50 unique works and ten assignment pages (nine weeks plus bonus). Works use JSON front matter followed by Markdown; assignments reference stable work IDs. Repeated books share files. PDFs/EPUBs are not fetched automatically. Original links, page ranges, chapter and timestamp instructions remain; external availability has not been checked.

Only `content`, `layouts`, `assets` and `static` are publication inputs. Other project paths, including inbox, reference material, Git state, agent instructions and publication status, are private inputs and never copied to public releases. Never place secrets in a publishable directory. An unlisted page is NOT private. Hugo configuration is fixed by the host helper; arbitrary module/theme downloads and build-time HTTP/command execution are disabled. Content and local templates can be edited without rebuilding a host.

## Protocol

1. GRILL agent completes an edit batch, runs `dump-publish check`, then `dump-publish submit` from the mounted project.
2. Submit rejects a local/unmounted fallback, copies an allowlisted source snapshot, detects source changes during copying, rejects symlinks/hidden/partial files, validates work references and source URLs, and locally renders using Hugo. Draft snapshot directories are ignored by NAS.
3. The snapshot receives a SHA-256 manifest and is atomically renamed into `.publishing/requests/<id>`.
4. NAS polls every 15 seconds after its previous job finishes, serializes with a file lock, privately copies the ready snapshot, checks its manifest and validates/builds using host-pinned Hugo. It never runs project scripts.
5. Complete output becomes a release; an atomic `current` symlink replacement publishes it. Failed builds preserve the previous release. Receipts under NAS state provide idempotency; copies in `.publishing/status` let the GRILL agent observe results.
6. Submit waits up to five minutes. A published receipt means success and allows removal of the request snapshot. Timeout means pending, NOT success; inspect the receipt before retrying. Failed/timed-out snapshots remain for diagnosis.

Private request snapshots are ordinary copies. Allow disk space for source staging and five retained output releases; reflink/content-addressed storage is a future optimization, not currently implemented. Receipts and failed/pending requests need periodic operator cleanup. There is no automatic full-project backup configured here; attach the project including books to the NAS backup policy before relying on it as the only copy.

Publisher isolation uses a dedicated Unix identity, read-only system, private network/tmp/devices, no home or secret-directory access, no capabilities, limited tasks/memory and a restricted write set. Operator-edited templates are trusted site code, not a multi-tenant untrusted-template sandbox. GRILL's existing managed Matrix agent also runs with the operator's Unix authority, not OS-enforced project isolation.

## NAS chat tools (pending complete harness rollout)

The current module prepares the existing Note to Self room for chat-only workspace tools. It configures the NAS backing project, the existing editor identity, and immutable named `check`, `publish`, `status` commands. The generic file interface cannot access `.publishing`; the commands receive separate `/commands/data/requests` (writable) and `/commands/data/status` (read-only) mounts inside the sandbox.

`submit-local` accepts only `/workspace` with these canonical command mounts, copies/validates the same four public input directories and reuses the existing snapshot/receipt protocol. `status-local` reports up to ten recent pending/completed requests. Normal `submit` still requires the expected NFS mount on GRILL. There is no new approval flow, operation journal, lock protocol or prepare/commit API. The operator assumes one editor at a time and explicitly requires GRILL to remain writable.

A requested site edit may proceed through publication without asking again. On timeout/interruption, inspect status before repeating publication. Host policy defines argv and mounts; writable project instructions only explain how to use the tools. These tools load only in the dedicated chat assistant, not ordinary Pi CLI sessions.

The NAS declaration also enables chat-only `download_file`/`send_file` in every enabled assistant chat. Downloads use a credential-free public-HTTPS sandbox and private 24-hour staging; a workspace destination is optional and available only in project-bound rooms. Sending is through the owner's Matrix account to the originating room and does not publish the file. The chat cannot read host paths or choose another destination. The consuming pi-harness input is pinned to `99fd69601b51886c241d67d5b0d11a7fdb420dbf` (source NAR `sha256-a3XX5yzRVnXgopTB1sWmoghbS4Ef8MiALvRiKhvMp/M=`). Cumulative Standards/Spec review and all final local gates passed; the only implementation finding was stale binary-protocol documentation, now corrected. The harness revision must be available from the configured GitHub source before a fresh NAS fetch can rebuild it. No host rebuild/restart or real submission was performed by this increment. The focused Python publisher suite now has 15 passing tests, including local queue separation, canonical sandbox entrypoint checks and pending/completed status. Full NAS service and bridge acceptance remain deployment checks.

## Matrix

`modules/cli/pi-harness/grill.nix` already configures the GRILL bot, `@beau:matrix.bepis.lol` operator and `projects = ~/documents/projects` workspace. No new token or bot is needed. After mounting the transferred project, associate a managed conversation with the existing `projects` workspace's `dump` directory using the installed bridge workflow. No room was created or session restarted by this change. Matrix attachments are received/processed on GRILL; the project AGENTS.md specifies inbox, untrusted-document handling, publication and success reporting.

## First deployment — order matters

See the separate project's README for exact transfer commands.

1. Review and track new files in the dotfiles checkout so Git-backed Nix flakes include them. Preserve unrelated work. Regenerate NAS/GRILL manifests if desired after tracking all intended modules.
2. Rebuild/activate **NAS first**. It creates directories/export and starts the publisher timer. Until a release is submitted, the new site intentionally returns 404.
3. Copy the local GRILL starter to `/var/lib/dump-site/project` on NAS using SSH/rsync. Exclude `.publishing`, `.git` and generated output; preserve NAS-created control directory ownership. Verify with a checksum dry-run.
4. Leave the source directory in all shells/agents, then rename the local starter to `~/documents/projects/dump-local-backup`. Do NOT delete it.
5. Rebuild/activate **GRILL**, access the project, and confirm `findmnt -T ~/documents/projects/dump` shows the intended NAS NFS mount. Never activate the mount over the only local copy.
6. Run site checks and first submission on GRILL; initialise project Git on the mounted copy if wanted. Connect the Matrix project conversation only after the mount is verified.

Use your normal per-host rebuild workflow. The implementation deliberately did not run rebuild/switch, generator package realization, or `nix flake check`.

## Validation

Performed without Nix builds:

- Python protocol tests: successful publication/idempotence, malformed references, symlink/partial rejection, private-path exclusion, source mutation, failed-build preservation, local-shadow refusal, status recovery and rollback.
- Initial content checks: 50 unique works, ten assignment pages, repeated-work references and source URL syntax.
- Nix syntax parsing for new modules, project flake and affected manifests.
- Focused offline evaluation of actual NAS/GRILL options via the local `flake.nix` outputs and cached inputs: DNS registration, shared-ingress HTTPS listeners, static root, publisher command, GRILL-only export and NFS automount all pass.
- LSP diagnostics and `git diff --check`.

**Outstanding:** Hugo was not installed locally and no tool packages were realized under the no-build instruction. Actual Hugo rendering, generated HTML/internal-link checks, host builds, NFS permissions under deployed identities, Matrix attachment flow, DNS/TLS and live HTTP/download acceptance must be checked after tooling/deployment. The project offers `python3 tests/check_content.py [rendered-output-directory]` for content and optional rendered-link checks. Do not equate fake-Hugo protocol tests with a successful Hugo render.

## Acceptance and rollback

After activation verify `/`, `/josh/`, library, all week/work pages and mobile navigation. Add a test PDF/EPUB through the GRILL conversation, check correct public file type/size and range downloads, then remove it. Add a generic new root without rebuilding. Submit deliberately invalid references and confirm the existing site survives. Confirm private project paths return 404. Confirm NAS still serves while GRILL is offline.

For rollback, stop the NAS publisher timer and wait for an active publisher job to finish. Run `sudo -u dump-publisher dump-publish rollback --release <retained-id>` (same lock as publication), then resume the timer. This is an operator maintenance action, not an agent content privilege. Pending requests can publish after the timer resumes. Do not manually edit published releases.
