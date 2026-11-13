#!/usr/bin/env python3
"""Temporary, offline #172 cutover. No Pi/process termination or Matrix client.

CLI: run, permit-text (read-only), gate (sandboxed consumer), gate-native.
The operator's /run permit is explicit consent/attestation, NOT exit proof.
"""
from contextlib import contextmanager
import ctypes
import fcntl
import grp
import hashlib
import json
import os
from pathlib import Path
import pwd
import select
import stat
import subprocess
import sys
import tempfile
import time


class Refused(RuntimeError):
    pass


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n"


def digest(data):
    return hashlib.sha256(data).hexdigest()


def lexical(path):
    path = Path(path)
    if not path.is_absolute() or str(path) != os.path.normpath(path) or "sops-secrets" in path.parts:
        raise Refused("Non-canonical or excluded path")
    return path


def checked(path):
    path = lexical(path)
    current = Path("/")
    for part in path.parts[1:]:
        current /= part
        if current.is_symlink():
            raise Refused("Symlink refused")
    return path


def regular(path, uid=None, mode=None):
    path = checked(path)
    info = path.lstat()
    if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1 or (uid is not None and info.st_uid != uid):
        raise Refused("Unsafe regular file")
    if mode is not None and stat.S_IMODE(info.st_mode) != mode:
        raise Refused("Unexpected file permissions")
    return info


def read_json(path, uid=None, mode=None):
    info = regular(path, uid, mode)
    if info.st_size > 131072:
        raise Refused("Oversized receipt/configuration")
    return json.loads(Path(path).read_bytes())


def sync_directory(path):
    fd = os.open(path, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def publish(parent, source, destination):
    # Relative descriptor operations prevent path substitution at publication.
    fd = os.open(checked(parent), os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        rename = ctypes.CDLL(None, use_errno=True).renameat2
        if rename(fd, os.fsencode(source), fd, os.fsencode(destination), 1) != 0:
            raise OSError(ctypes.get_errno(), "No-replace publication refused")
        os.fsync(fd)
    finally:
        os.close(fd)


def durable_json(path, value, mode, uid, gid, replace=False):
    path = checked(path)
    fd, temporary = tempfile.mkstemp(prefix=f".{path.name}-partial-", dir=path.parent)
    try:
        os.fchmod(fd, mode)
        os.fchown(fd, uid, gid)
        with os.fdopen(fd, "wb") as stream:
            stream.write(canonical(value).encode())
            stream.flush()
            os.fsync(stream.fileno())
        if replace:
            # Only boot readiness, in the root-owned runtime directory, replaces.
            os.replace(temporary, path)
            sync_directory(path.parent)
        else:
            publish(path.parent, Path(temporary).name, path.name)
    except BaseException:
        # Unpublished files are retained, never adopted or treated as success.
        raise


def private_directory(path, uid, gid, mode=0o700):
    path = checked(path)
    try:
        path.mkdir(mode=mode)
        os.chmod(path, mode)  # Set only a newly created directory, independent of umask.
        os.chown(path, uid, gid)
        sync_directory(path.parent)
    except FileExistsError:
        pass
    info = path.lstat()
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != uid or stat.S_IMODE(info.st_mode) != mode:
        raise Refused("Unsafe existing directory")
    return path


def tree(root, destination=None, owner=None):
    """Descriptor-relative, no-follow byte inventory; optional independent copy."""
    root = checked(root)
    fd = os.open("/", os.O_RDONLY | os.O_DIRECTORY)
    try:
        for component in root.parts[1:]:
            child = os.open(component, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=fd)
            os.close(fd)
            fd = child
        result = []

        def visit(directory, relative, output):
            result.append([relative, "directory"])
            for name in sorted(os.listdir(directory)):
                if name == "sops-secrets":
                    raise Refused("Excluded directory in capture")
                before = os.stat(name, dir_fd=directory, follow_symlinks=False)
                item = f"{relative}/{name}" if relative else name
                flags = os.O_RDONLY | os.O_NOFOLLOW
                if stat.S_ISDIR(before.st_mode):
                    flags |= os.O_DIRECTORY
                elif not stat.S_ISREG(before.st_mode):
                    raise Refused("Symlink or special capture file")
                child = os.open(name, flags, dir_fd=directory)
                try:
                    opened = os.fstat(child)
                    if (opened.st_dev, opened.st_ino) != (before.st_dev, before.st_ino):
                        raise Refused("Source changed while opening")
                    target = output / name if output is not None else None
                    if stat.S_ISDIR(opened.st_mode):
                        if target is not None:
                            target.mkdir(mode=0o700)
                        visit(child, item, target)
                    else:
                        value = hashlib.sha256()
                        size = 0
                        writer = target.open("xb") if target is not None else None
                        try:
                            while chunk := os.read(child, 1024 * 1024):
                                value.update(chunk)
                                size += len(chunk)
                                if writer:
                                    writer.write(chunk)
                            after = os.fstat(child)
                            if (after.st_size, after.st_mtime_ns, after.st_ctime_ns) != (opened.st_size, opened.st_mtime_ns, opened.st_ctime_ns) or size != opened.st_size:
                                raise Refused("Source changed while reading")
                            if writer:
                                writer.flush()
                                os.fchmod(writer.fileno(), 0o600)
                                os.fchown(writer.fileno(), *owner)
                                os.fsync(writer.fileno())
                            result.append([item, "file", size, value.hexdigest()])
                        finally:
                            if writer:
                                writer.close()
                finally:
                    os.close(child)
            if output is not None:
                os.chown(output, *owner)
                sync_directory(output)

        visit(fd, "", destination)
        return result
    finally:
        os.close(fd)


class Runtime:
    def __init__(self, config, authority_uid=0, proc=Path("/proc"), cgroups=Path("/sys/fs/cgroup")):
        self.c = config
        self.authority_uid = authority_uid
        self.proc, self.cgroups = proc, cgroups
        user = pwd.getpwnam(config["user"])
        self.uid = user.pw_uid
        self.state = lexical(config["state"])
        self.control, self.runtime = lexical(config["control"]), lexical(config["runtime"])
        self.completion = self.control / "complete.json"
        self.ready = self.runtime / "ready.json"
        identity = {k: config[k] for k in ("version", "id", "host", "user", "home", "state", "roots", "botUserId", "operatorUserId")}
        self.identity = digest(canonical(identity).encode())
        roots = [lexical(x["original"]) for x in config["roots"]]
        for destination in (self.state, self.control, self.runtime):
            if any(destination == root or root in destination.parents for root in roots):
                raise Refused("Destination overlaps an original root")
        if self.control == self.state or self.control in self.state.parents or self.state in self.control.parents:
            raise Refused("Capture control and active state must be distinct")

    def command(self, argv, user=False, timeout=60, group=None):
        if user:
            argv = [self.c["tools"]["runuser"], "-u", self.c["user"], *(["-g", group] if group else []), "--", self.c["tools"]["env"], "-i",
                    f"HOME={self.c['home']}", f"USER={self.c['user']}", f"LOGNAME={self.c['user']}",
                    f"XDG_RUNTIME_DIR=/run/user/{self.uid}", f"DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/{self.uid}/bus",
                    "PATH=/nonexistent", *argv]
        result = subprocess.run(argv, stdin=subprocess.DEVNULL, capture_output=True, timeout=timeout, check=False,
                                env={"HOME": self.c["home"], "PATH": "/nonexistent"})
        if result.returncode:
            # Child stderr may contain state values; retain no unsolicited payloads.
            raise Refused(f"Required command failed ({Path(argv[0]).name}, exit {result.returncode})")
        if len(result.stdout) > 131072:
            raise Refused("Oversized command result")
        return result.stdout.decode("utf-8", errors="strict").strip()

    def controller(self, user, *args):
        return self.command([self.c["tools"]["systemctl"], *( ["--user"] if user else []), "--no-pager", *args], user=user)

    def unit(self, user, name):
        output = self.controller(user, "show", name, "--property=ActiveState,SubState,MainPID,ControlGroup,LoadState")
        return dict(line.split("=", 1) for line in output.splitlines() if "=" in line)

    def processes(self):
        blocked = []
        for entry in self.proc.iterdir():
            if not entry.name.isdigit():
                continue
            try:
                fields = dict(line.split(":", 1) for line in (entry / "status").read_text().splitlines() if ":" in line)
                if int(fields["Uid"].split()[0]) != self.uid:
                    continue
                if fields.get("State", "").strip().startswith("Z"):
                    continue  # Kernel-exited task; surviving children are separate.
                name = fields["Name"].strip()
                executable = (entry / "exe").readlink().name
                # Supplementary known Pi/finite Git/setup families, not an
                # exhaustive writer inventory. A changed comm cannot hide Pi.
                if name == "pi" or executable in ("pi", ".pi-wrapped") or name == "direnv" or name == "git" or name.startswith("git-") or name.startswith("pi-task") or name == "tmux_project":
                    blocked.append(int(entry.name))
                elif name in ("python", "python3", "node", "MainThread", "bun") or executable in ("python3", "node", "bun"):
                    with (entry / "cmdline").open("rb") as stream:
                        raw = stream.read(65537)
                    if len(raw) > 65536:
                        raise Refused("Unbounded process arguments; inspect closure independently")
                    if any(x.endswith((b"/task-git.py", b"/task-worker.js", b"/pi-task-workspace", b"/pi-coding-agent/dist/cli.js")) for x in raw.split(b"\0")[:4]):
                        blocked.append(int(entry.name))
            except FileNotFoundError:
                if entry.exists():
                    raise Refused("Incomplete process evidence; closure is unproven") from None
                continue
            except (OSError, KeyError, ValueError):
                raise Refused("Unreadable process evidence; closure is unproven") from None
        if blocked:
            raise Refused("Pi/task/Git activity remains: " + ",".join(map(str, sorted(blocked))))

    def cgroup_pids(self, group):
        if not group:
            return set()
        if not group.startswith("/") or ".." in Path(group).parts:
            raise Refused("Invalid cgroup evidence")
        path = self.cgroups / group.lstrip("/")
        if not path.exists():
            return set()
        return {int(pid) for file in path.rglob("cgroup.procs") for pid in file.read_text().split()}

    def permit_text(self):
        return f"{self.c['id']} {self.c['host']} {digest(canonical(self.c).encode())}\n"

    def require_paused(self):
        # Syncthing requires paired --config/--data, or --home for both.
        paused = self.command([self.c["tools"]["syncthing"], "cli", f"--home={self.c['syncthingConfig']}", "config", "folders", "state-sync", "paused", "get"], user=True)
        if paused != "true":
            raise Refused("Local state-sync is not confirmed paused; both hosts must be paused by the operator")

    def preflight(self):
        permit = checked(self.c["permit"])
        info = regular(permit, self.authority_uid, 0o600)
        if not 0 <= time.time() - info.st_mtime <= 3600 or permit.read_text() != self.permit_text():
            raise Refused("Missing/fresh maintenance permit required")
        self.processes()
        bridge = self.unit(True, "pi-matrix-bridge.service")
        if int(bridge.get("MainPID", "0")) or self.cgroup_pids(bridge.get("ControlGroup", "")):
            raise Refused("New bridge is already running; no offline conversion permitted")
        self.require_paused()
        for user, units in ((True, self.c["userConsumers"]), (False, self.c["systemConsumers"])):
            for name in units:
                facts = self.unit(user, name)
                main = int(facts.get("MainPID", "0"))
                for pid in self.cgroup_pids(facts.get("ControlGroup", "")) - {main}:
                    try:
                        executable = (self.proc / str(pid) / "exe").readlink()
                    except OSError:
                        raise Refused("Unconfirmed consumer descendant") from None
                    if not (name == "pi-managed-session-relay.service" and executable.name == "pi-managed-session-relay-lock" and str(executable).startswith("/nix/store/")):
                        raise Refused("Consumer has a live helper; await completion before stopping it")
        return {"permit": digest(permit.read_bytes()), "observedAt": int(time.time()),
                "operatorPrerequisites": "Closed writers/finished creators and BOTH hosts' paused replication are separately attested; local probes are not exhaustive arbitrary-writer proof."}

    @contextmanager
    def exit_barrier(self, pids):
        handles = []
        try:
            for pid in pids:
                try:
                    handles.append(os.pidfd_open(pid))
                except ProcessLookupError:
                    pass  # The observed process is already kernel-exited.
            def verify():
                poll = select.poll()
                for fd in handles:
                    poll.register(fd, select.POLLIN)
                if len(poll.poll(0)) != len(handles):
                    raise Refused("Known consumer process has not exited")
            yield verify
        finally:
            for fd in handles:
                os.close(fd)

    def stop_consumers(self):
        for user, units in ((True, self.c["userConsumers"]), (False, self.c["systemConsumers"])):
            if units:
                live, groups, pids = [], {}, set()
                for name in units:
                    facts = self.unit(user, name)
                    groups[name] = facts.get("ControlGroup", "")
                    members = self.cgroup_pids(groups[name])
                    main = int(facts.get("MainPID", "0"))
                    pids.update(members | ({main} if main else set()))
                    if facts.get("ActiveState") not in ("inactive", "failed") or main or members:
                        live.append(name)
                with self.exit_barrier(pids) as verify_exit:
                    if live:
                        self.controller(user, "stop", *live)
                    # Only obsolete user units are masked. NAS replacements use
                    # readiness gates, never a lingering mask of their own name.
                    if user:
                        self.controller(True, "mask", "--runtime", *units)
                    for name in units:
                        facts = self.unit(user, name)
                        remaining = self.cgroup_pids(groups[name]) | self.cgroup_pids(facts.get("ControlGroup", ""))
                        if facts.get("ActiveState") not in ("inactive", "failed") or int(facts.get("MainPID", "0")) or remaining:
                            raise Refused("Consumer exit is unproven")
                        if user and facts.get("LoadState") != "masked":
                            raise Refused("Legacy restart prevention is unconfirmed; effective unit is not masked")
                    verify_exit()  # A control ACK or missing attachment is not exit.
        self.processes()
        if self.c["systemConsumers"]:
            facts = self.unit(False, "systemd-tmpfiles-clean.service")
            if facts.get("ActiveState") not in ("inactive", "failed"):
                raise Refused("Wait for in-progress tmpfiles cleanup")

    def grouping(self, cwd):
        if not any(cwd == root or Path(root) in Path(cwd).parents for root in self.c["workspaceRoots"]):
            return None
        try:
            checked(cwd)
            top = self.command([self.c["tools"]["git"], "--no-optional-locks", "-c", "core.fsmonitor=false", "-C", cwd, "rev-parse", "--path-format=absolute", "--show-toplevel", "--git-common-dir"], user=True).splitlines()
            if len(top) == 2 and all(str(checked(value)) == value for value in top):
                return {"project": top[1], "checkout": top[0]}
        except (OSError, Refused):
            pass
        # Unproven/non-Git grouping stays held; never guess replacement Spaces.
        return None

    def descriptor(self, snapshot, evidence):
        by_id = {}
        for root in self.c["roots"]:
            if root["role"] != "native":
                continue
            for file in (snapshot / root["name"]).rglob("*.jsonl"):
                try:
                    with file.open("rb") as stream:
                        first = stream.readline(8193)
                    header = json.loads(first) if len(first) <= 8192 and first.endswith(b"\n") else {}
                    if header.get("type") == "session" and header.get("version") == 3 and isinstance(header.get("id"), str) and isinstance(header.get("cwd"), str):
                        original = str(Path(root["original"]) / file.relative_to(snapshot / root["name"]))
                        by_id.setdefault(header["id"], []).append((original, header["cwd"]))
                except (OSError, ValueError):
                    pass  # Converter reports missing/damaged/ambiguous identities.
        current, groupings = {}, {}
        manifests = next(root for root in self.c["roots"] if root["role"] == "manifests")
        for file in (snapshot / manifests["name"]).glob("conv_*.json"):
            row = read_json(file)
            matches = by_id.get(row.get("piSessionId"), [])
            if len(matches) == 1:
                current[row["piSessionId"]] = matches[0][0]
                grouping = self.grouping(matches[0][1])
                if grouping:
                    groupings[row["conversationId"]] = grouping
        return {"version": 1, "hostId": self.c["host"], "botUserId": self.c["botUserId"], "operatorUserId": self.c["operatorUserId"],
                "quiescence": canonical(evidence).strip(), "roots": self.c["roots"], "unavailable": [], "currentFiles": current, "groupings": groupings}

    def capture_gid(self):
        try:
            return grp.getgrnam(self.c["captureGroup"]).gr_gid
        except KeyError:
            raise Refused("Private capture group is not installed") from None

    def freeze(self, directory):
        # Every inode was created by the authority under its protected parent;
        # never chown a user-owned export in place or follow foreign links.
        directory = checked(directory)
        group = self.capture_gid()
        paths = [*directory.rglob("*"), directory]
        for path in paths:
            info = checked(path).lstat()
            if info.st_uid != self.authority_uid or not (stat.S_ISDIR(info.st_mode) or stat.S_ISREG(info.st_mode)) or (stat.S_ISREG(info.st_mode) and info.st_nlink != 1):
                raise Refused("Foreign capture/export ownership; nothing re-owned")
        for path in paths:  # Root directory becomes accessible only after children.
            directory_entry = path.is_dir()
            os.chown(path, self.authority_uid, group, follow_symlinks=False)
            os.chmod(path, 0o550 if directory_entry else 0o440)
            if not directory_entry:
                with path.open("rb") as stream:
                    os.fsync(stream.fileno())
        for path in reversed(paths):
            if path.is_dir():
                sync_directory(path)
        self.frozen(directory)

    def frozen(self, directory):
        directory = checked(directory)
        group = self.capture_gid()
        for path in [directory, *directory.rglob("*")]:
            info = checked(path).lstat()
            mode = 0o550 if stat.S_ISDIR(info.st_mode) else 0o440
            if info.st_uid != self.authority_uid or info.st_gid != group or stat.S_IMODE(info.st_mode) != mode or not (stat.S_ISDIR(info.st_mode) or stat.S_ISREG(info.st_mode)) or (stat.S_ISREG(info.st_mode) and info.st_nlink != 1):
                raise Refused("Capture/export is not frozen under authority ownership")

    def compare_source(self, snapshot):
        descriptor = read_json(snapshot / "source.json", self.authority_uid, 0o440)
        if descriptor["roots"] != self.c["roots"] or descriptor["hostId"] != self.c["host"] or descriptor["botUserId"] != self.c["botUserId"] or descriptor["operatorUserId"] != self.c["operatorUserId"]:
            raise Refused("Foreign capture descriptor")
        for root in self.c["roots"]:
            if tree(snapshot / root["name"]) != tree(root["original"]):
                raise Refused("Old source changed since capture; preserve evidence and reconcile")

    def capture(self, evidence):
        snapshot = self.control / "source"
        if snapshot.exists() or snapshot.is_symlink():
            self.frozen(snapshot)
            self.compare_source(snapshot)
            return snapshot
        # Root owns the parent: an unprivileged account cannot redirect a
        # partially built privileged capture by renaming/replacing its directory.
        staging = Path(tempfile.mkdtemp(prefix=".source-partial-", dir=self.control))
        for root in self.c["roots"]:
            output = staging / root["name"]
            output.mkdir(mode=0o700)
            copied = tree(root["original"], output, (self.authority_uid, os.getgid()))
            if copied != tree(root["original"]):
                raise Refused("Source changed during independent capture")
        descriptor = self.descriptor(staging, evidence)
        durable_json(staging / "source.json", descriptor, 0o600, self.authority_uid, os.getgid())
        self.freeze(staging)
        self.compare_source(staging)
        self.boundary("capture-before-publish")
        publish(self.control, staging.name, snapshot.name)
        self.boundary("capture-after-publish")
        return snapshot

    def converter(self, verb, source, target=None):
        argv = [self.c["tools"]["bwrap"], "--bind", "/", "/", "--dev-bind", "/dev", "/dev", "--ro-bind", str(source), str(source),
                "--", self.c["tools"]["converter"], verb, str(source)]
        if target is not None:
            argv.append(str(target))
        # Inventory/export never open a runtime writer and run as the capture
        # authority. Their output has never been writable by the ledger user.
        # Import/check run as the native owner, as required by the converter.
        owner = verb in ("import", "check")
        return json.loads(self.command(argv, user=owner, timeout=1200, group=self.c["captureGroup"] if owner else None))

    def destination_identity(self):
        directory = checked(self.state).lstat()
        if not stat.S_ISDIR(directory.st_mode) or directory.st_uid != self.uid or stat.S_IMODE(directory.st_mode) != 0o700:
            raise Refused("Unsafe active state directory")
        ledger = regular(self.state / "bridge.sqlite", self.uid, 0o600)
        regular(self.state / "migration-receipt.json", self.uid, 0o600)
        with (self.state / "bridge.sqlite").open("rb") as stream:
            if stream.read(16) != b"SQLite format 3\0":
                raise Refused("Imported ledger header missing")
        return {"device": ledger.st_dev, "inode": ledger.st_ino, "receipt": digest((self.state / "migration-receipt.json").read_bytes())}

    def completed(self, validate_destination=True):
        value = read_json(self.completion, self.authority_uid, 0o644)
        if value.get("version") != 1 or value.get("identity") != self.identity or (validate_destination and value.get("destination") != self.destination_identity()):
            raise Refused("Completion/destination identity changed; no automatic reimport")
        return value

    def user_manager_present(self):
        return any(Path(f"/run/user/{self.uid}/{socket}").exists() for socket in ("systemd/private", "bus"))

    def start_consumers(self):
        if not self.c["startAfterMigration"]:
            return
        if self.c["systemConsumers"]:
            self.controller(False, "start", "--no-block", *self.c["systemConsumers"])
        # A lingering user's manager may start later during boot. Its default
        # target also pulls in the gated bridge; do not start a user manager here.
        if self.user_manager_present():
            self.controller(True, "daemon-reload")
            self.controller(True, "start", "--no-block", "pi-matrix-bridge.service")

    def boot_id(self):
        return (self.proc / "sys/kernel/random/boot_id").read_text().strip()

    def publish_ready(self, completed):
        durable_json(self.ready, {"version": 1, "identity": self.identity, "boot": self.boot_id(), "completion": digest(canonical(completed).encode())},
                     0o644, self.authority_uid, os.getgid(), replace=True)

    def boundary(self, _name):
        pass


def run(runtime):
    r = runtime
    private_directory(r.control, r.authority_uid, os.getgid(), 0o755)
    lock = r.control / "run.lock"
    fd = os.open(lock, os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW, 0o600)
    try:
        regular(lock, r.authority_uid, 0o600)
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise Refused("Another cutover job is running") from None
        return execute(r)
    finally:
        os.close(fd)


def execute(r):
    private_directory(r.runtime, r.authority_uid, os.getgid(), 0o755)
    if r.ready.exists() or r.ready.is_symlink():
        regular(r.ready, r.authority_uid, 0o644)
        r.ready.unlink()  # Withdraw only our ephemeral readiness, not state/history.
        sync_directory(r.runtime)
    if r.completion.exists() or r.completion.is_symlink():
        r.publish_ready(r.completed())
        r.start_consumers()
        return "already complete; no source copy, converter or old-state replay"
    evidence = r.preflight()
    r.stop_consumers()
    source = r.capture(evidence)
    r.frozen(source)
    r.compare_source(source)
    inventory = r.converter("inventory", source)
    bundle = r.control / "bundle"
    exported = r.converter("export", source, bundle)
    if exported.get("source") != inventory.get("source"):
        raise Refused("Export differs from the frozen capture")
    r.freeze(bundle)
    r.boundary("export-complete")
    status = r.converter("import", bundle, r.state)
    r.boundary("import-complete")
    checked_status = r.converter("check", bundle, r.state)
    for value in (status, checked_status):
        if value.get("started") is not False or value.get("pristine") is not True or value.get("nativeUnchanged") is not True:
            raise Refused("Import is not pristine/not-started/native-unchanged; preserve and reconcile")
    if status.get("source") != checked_status.get("source") or checked_status.get("source") != inventory.get("source"):
        raise Refused("Migration source changed")
    r.compare_source(source)
    complete = {"version": 1, "identity": r.identity, "source": checked_status["source"], "destination": r.destination_identity()}
    r.boundary("completion-before-publish")
    durable_json(r.completion, complete, 0o644, r.authority_uid, os.getgid())
    r.boundary("completion-after-publish")
    r.publish_ready(complete)
    r.start_consumers()
    return ("migration complete; replacement startup requested, not live acceptance" if r.c["startAfterMigration"]
            else "migration complete; inspect private migration-report.json before separately approved startup")


def gate(runtime, timeout=1200, native=False):
    r = runtime
    if not r.c["startAfterMigration"]:
        return False
    deadline = time.monotonic() + timeout
    while True:
        try:
            ready = read_json(r.ready, r.authority_uid, 0o644)
            # NAS sandboxes intentionally cannot access the owner's home.
            # They trust the root-owned completion/readiness pair; the bridge
            # additionally checks its current destination identity itself.
            complete = r.completed(validate_destination=native)
            if ready != {"version": 1, "identity": r.identity, "boot": r.boot_id(), "completion": digest(canonical(complete).encode())}:
                raise Refused("Runtime readiness identity changed")
            return True
        except FileNotFoundError:
            if time.monotonic() >= deadline or r.unit(False, "pi-native-cutover-172.service").get("ActiveState") == "failed":
                return False
            time.sleep(0.5)


def main():
    try:
        if len(sys.argv) != 3 or sys.argv[1] not in ("run", "permit-text", "gate", "gate-native"):
            raise Refused("Usage: pi-native-cutover-172 run|permit-text|gate|gate-native CONFIG")
        # Public immutable Nix configuration may be hard-linked by store
        # optimisation. Private receipts, unlike this configuration, may not.
        config = json.loads(Path(sys.argv[2]).read_text())
        runtime = Runtime(config)
        if sys.argv[1] == "permit-text":
            print(runtime.permit_text(), end="")
        elif sys.argv[1] == "run":
            if os.geteuid() != 0:
                raise Refused("The systemd cutover job requires root")
            print(run(runtime))
        else:
            return 0 if gate(runtime, native=sys.argv[1] == "gate-native") else 1
        return 0
    except (OSError, ValueError, Refused, subprocess.TimeoutExpired) as error:
        print(f"pi-native-cutover-172: {type(error).__name__}: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
