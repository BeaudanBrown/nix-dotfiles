# Synchronized Pi sessions

## Purpose

Primary fleet hosts synchronize Pi's native multi-project session tree through
Syncthing. The backing directory is:

```text
~/.local/state/syncthing/pi/sessions
```

NixOS bind-mounts that directory over Pi's native session root:

```text
~/.pi/agent/sessions
```

Pi therefore keeps its upstream per-project layout unchanged:

```text
~/.pi/agent/sessions/
└── --home-beau-documents-projects-pi-harness--/
    └── <timestamp>_<session-id>.jsonl
```

Do not set `PI_CODING_AGENT_SESSION_DIR` for this workflow. That variable names
one exact flat directory; it does not configure the parent of Pi's normal
per-project directories. `PI_CODING_AGENT_DIR` is also unsuitable because it
would move and synchronize settings, authentication, and other host-local data.

Git repositories, credentials, caches, sockets, databases, and runtime locks
remain outside the synchronized-state root. Syncthing replicates whole session
files, so never run the same logical Pi session on two hosts concurrently. Exit
it on one host, wait for convergence, and only then resume it elsewhere.

## Pre-activation migration

The mount hides the old local directory without deleting it. Complete migration
before activating the mount on a host:

1. Exit every Pi process on that host.
2. Keep `~/.pi/agent/sessions` intact as the rollback source.
3. On the initial authoritative host (grill), refresh the backing directory from
   the complete local tree. Plain `rsync -a` is intentional here: it captures
   final appends made after the earlier copy while Pi was still active.

   ```sh
   synchronized_sessions="$HOME/.local/state/syncthing/pi/sessions"
   rsync -a \
     "$HOME/.pi/agent/sessions/" \
     "$synchronized_sessions/"
   ```

4. Relocate any JSONL files incorrectly created at the backing root by the
   earlier flat-directory configuration. This preserves each file and derives
   the same project key Pi uses from its session header:

   ```sh
   find "$synchronized_sessions" -maxdepth 1 -type f -name '*.jsonl' -print0 |
     while IFS= read -r -d '' session_file; do
       session_cwd="$(head -n 1 "$session_file" | jq -er '.cwd')" || exit 1
       project_key="--${session_cwd#/}--"
       project_key="${project_key//\//-}"
       project_key="${project_key//:/-}"
       destination="$synchronized_sessions/$project_key/$(basename "$session_file")"
       if test -e "$destination"; then
         printf 'Refusing collision: %s\n' "$destination" >&2
         exit 1
       fi
       install -d -m 0700 "$(dirname "$destination")"
       mv "$session_file" "$destination"
     done
   ```

5. Confirm there are no remaining root-level sessions or Syncthing conflicts:

   ```sh
   find "$synchronized_sessions" -maxdepth 1 -type f -name '*.jsonl' -print
   find "$synchronized_sessions" -type f -name '*sync-conflict*' -print
   ```

Both commands must produce no output. Wait for `state-sync` convergence before
activating or migrating another host.

## Activation

Evaluate target configurations before deployment:

```sh
nix eval --raw .#nixosConfigurations.grill.config.system.build.toplevel.drvPath
nix eval --raw .#nixosConfigurations.t480.config.system.build.toplevel.drvPath
```

Deploy through the normal user-approved fleet workflow while Pi remains stopped.
No logout is required because no login-session environment variable is involved.

Verify the mount and permissions:

```sh
findmnt --target "$HOME/.pi/agent/sessions"
stat -c '%a %U %G %n' \
  "$HOME/.local/state/syncthing/pi/sessions" \
  "$HOME/.pi/agent/sessions"
test "$(stat -c '%d:%i' "$HOME/.local/state/syncthing/pi/sessions")" = \
  "$(stat -c '%d:%i' "$HOME/.pi/agent/sessions")"
syncthing cli config folders state-sync dump-json
```

`findmnt` must report a bind mount. The inode comparison must succeed, proving
both paths expose the same directory.

## Grill acceptance

After activating grill:

1. Start `pi -r` in a project with migrated sessions and verify the full expected
   list is visible.
2. Create a disposable named session such as `matrix-sync-smoke`, send one
   distinctive prompt, wait for completion, and exit Pi.
3. Confirm the new file appears beneath the matching encoded project directory,
   not directly at the synchronized root.
4. Wait for Syncthing to report `state-sync` up to date on nas.
5. Require this command to produce no output:

   ```sh
   find "$HOME/.local/state/syncthing/pi/sessions" \
     -type f -name '*sync-conflict*' -print
   ```

## Grill-to-t480 acceptance

When t480 testing resumes:

1. Stop Pi on both hosts and wait for convergence.
2. Inventory t480's old local tree against the converged backing tree. Resolve
   any same-path difference explicitly, then copy only missing files with
   `rsync -a --ignore-existing`; do not overwrite sessions received from grill.
3. Activate t480's mount, run `pi -r`, select `matrix-sync-smoke`, and verify its
   complete history.
4. Add one distinctive t480 turn, exit, and wait for convergence.
5. Resume on grill and verify the t480 turn appears.
6. Confirm no `sync-conflict` files exist on either host.

Record the session name, convergence, successful resume, and conflict search on
the tracking issue.

## Diagnostics

```sh
systemctl status syncthing.service
findmnt --target "$HOME/.pi/agent/sessions"
syncthing cli show system
syncthing cli config folders state-sync dump-json
find "$HOME/.local/state/syncthing/pi/sessions" \
  -type f -name '*sync-conflict*' -print
```

If a session is missing, verify that its JSONL file is under an encoded project
directory, that the header `cwd` matches the current project, and that the bind
mount is active. Do not copy a live JSONL file or resolve a conflict by choosing
the newest mtime without inspecting which conversation turns each file contains.

## Rollback

Stop Pi and revert the NixOS module to remove the mount. The original local
`~/.pi/agent/sessions` directory becomes visible again after unmounting; the
synchronized backing directory remains untouched. Do not delete either copy
until cross-host acceptance is complete.
