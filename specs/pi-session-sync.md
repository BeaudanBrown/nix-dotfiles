# Synchronized Pi sessions

## Purpose

Primary fleet hosts store Pi conversation files under the Syncthing
`state-sync` folder:

```text
~/.local/state/syncthing/pi/sessions
```

Pi receives this location through `PI_CODING_AGENT_SESSION_DIR`. Pi's precedence
is `--session-dir`, then `PI_CODING_AGENT_SESSION_DIR`, then `sessionDir` in its
settings file. Git repositories, credentials, caches, sockets, databases, and
runtime locks remain outside the synchronized-state root.

Syncthing replicates whole session files. Never run the same logical Pi session
on two hosts concurrently. Stop or leave the session on one host, wait for
Syncthing convergence, and only then resume it on another host.

## Activation

Evaluate both target configurations before deployment:

```sh
nix eval --raw .#nixosConfigurations.grill.config.system.build.toplevel.drvPath
nix eval --raw .#nixosConfigurations.t480.config.system.build.toplevel.drvPath
```

Deploy through the normal user-approved fleet workflow. Do not activate both
hosts while either is running a Pi process that will be migrated. Start a new
login shell after activation because an existing shell retains its old session
environment.

On each host, verify:

```sh
printf '%s\n' "$PI_CODING_AGENT_SESSION_DIR"
test "$PI_CODING_AGENT_SESSION_DIR" = "$HOME/.local/state/syncthing/pi/sessions"
test -d "$PI_CODING_AGENT_SESSION_DIR"
stat -c '%a %U %G %n' "$HOME/.local/state/syncthing" "$PI_CODING_AGENT_SESSION_DIR"
syncthing cli config folders state-sync dump-json
```

The synchronized-state root and Pi directory must be owned by the primary user
and inaccessible to other users through their parent directory.

## One-time migration

Keep `~/.pi/agent/sessions` intact as the rollback source. On each host:

1. Exit all Pi processes.
2. Confirm the new environment variable and directory checks above.
3. Inspect for relative filenames that already exist in both old and new roots.
   Identical files need no action. Stop and resolve any differing collision
   before copying.
4. Copy only missing files while preserving timestamps and modes:

   ```sh
   rsync -a --ignore-existing \
     "$HOME/.pi/agent/sessions/" \
     "$PI_CODING_AGENT_SESSION_DIR/"
   ```

5. Wait for the filesystem watcher and confirm `state-sync` is up to date in
   the Syncthing UI before migrating or opening sessions on another host. The
   configured watcher delay is ten seconds, but convergence may take longer.

Do not delete the old session directory during initial rollout.

## Grill-to-t480 acceptance test

1. Ensure no Pi process is using the test conversation on t480.
2. On grill, start Pi from a new login shell and create a disposable named
   session such as `matrix-sync-smoke`. Send one distinctive prompt, wait for
   the response to finish, then exit Pi.
3. Wait for Syncthing to report `state-sync` up to date on both hosts.
4. On t480, start a new login shell, run `pi -r`, select
   `matrix-sync-smoke`, and verify its complete prompt/response history.
5. Resume it, add one distinctive t480 turn, exit, and verify that turn appears
   back on grill only after convergence.
6. On both hosts, require this command to produce no output:

   ```sh
   find "$PI_CODING_AGENT_SESSION_DIR" -type f -name '*sync-conflict*' -print
   ```

Record the session name, Syncthing convergence, successful resume, and empty
conflict search on the tracking issue. Remove the disposable session only after
acceptance evidence is captured.

## Diagnostics

Check service and folder state without reading conversation content:

```sh
systemctl status syncthing.service
syncthing cli show system
syncthing cli config folders state-sync dump-json
find "$PI_CODING_AGENT_SESSION_DIR" -type f -name '*sync-conflict*' -print
```

If a session is missing, first confirm the active shell's environment, then the
folder path on both hosts, and finally Syncthing connectivity and pending data.
Do not copy a live JSONL file or resolve a conflict by choosing the newest
mtime without inspecting which conversation turns each file contains.

## Rollback

Stop Pi, unset `PI_CODING_AGENT_SESSION_DIR` in the current shell (or use
`--session-dir "$HOME/.pi/agent/sessions"`), and resume from the untouched old
session directory. Reverting the Nix module restores the default Pi location;
it does not delete synchronized or old session files.
