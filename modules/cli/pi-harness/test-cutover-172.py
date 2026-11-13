"""Disposable tests for the public run/gate cutover interface. No live controls."""
from contextlib import closing, contextmanager
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import importlib.util
import json
import os
from pathlib import Path
import pwd
import shutil
import signal
import sqlite3
import subprocess
import sys
import tempfile
import threading
import unittest
from xml.etree import ElementTree

spec = importlib.util.spec_from_file_location("cutover", Path(__file__).with_name("cutover-172.py"))
cutover = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cutover)


class FixtureRuntime(cutover.Runtime):
    def __init__(self, config, fault=None, kill=False):
        super().__init__(config, authority_uid=os.getuid(), proc=Path(config["testProc"]), cgroups=Path(config["testCgroups"]))
        self.operations = []
        self.units = {}
        self.paused = "true"
        self.fault, self.kill = fault, kill
        self.import_status = {"started": False, "pristine": True, "nativeUnchanged": True}
        self.converter_calls = []

    def controller(self, user, *args):
        if args[0] == "show":
            facts = self.units.get(args[1], {"ActiveState": "inactive", "SubState": "dead", "MainPID": "0", "ControlGroup": "", "LoadState": "not-found"})
            return "\n".join(f"{k}={v}" for k, v in facts.items())
        self.operations.append((user, *args))
        if args[0] == "stop":
            for unit in args[1:]:
                group = self.units.get(unit, {}).get("ControlGroup")
                if group:
                    for file in (self.cgroups / group.lstrip("/")).rglob("cgroup.procs"):
                        file.write_text("")
                self.units[unit] = {"ActiveState": "inactive", "SubState": "dead", "MainPID": "0", "ControlGroup": "", "LoadState": "loaded"}
        if args[0] == "mask" and not getattr(self, "ineffective_mask", False):
            for unit in args[1:]:
                if unit.startswith("--"):
                    continue
                self.units.setdefault(unit, {"ActiveState": "inactive", "MainPID": "0", "ControlGroup": ""})["LoadState"] = "masked"
        return ""

    def command(self, argv, user=False, timeout=60, group=None):
        if argv[0] == self.c["tools"]["syncthing"]:
            return self.paused
        if argv[0] == self.c["tools"]["git"]:
            raise cutover.Refused("Synthetic non-Git cwd remains held")
        raise AssertionError(f"Unexpected command in fixture: {argv[0]}")

    @contextmanager
    def exit_barrier(self, _pids):
        def verify():
            if not getattr(self, "exited", True):
                raise cutover.Refused("Known consumer process has not exited")
        yield verify

    def start_consumers(self):
        if self.c["startAfterMigration"]:
            self.operations.append(("approved-start",))

    def converter(self, verb, source, target=None):
        self.converter_calls.append(verb)
        source_id = "synthetic-seal"
        if verb == "inventory":
            return {"source": source_id}
        if verb == "export":
            if not target.exists():
                shutil.copytree(source, target)
            return {"source": source_id}
        if verb == "import" and not target.exists():
            target.mkdir(mode=0o700)
            with closing(sqlite3.connect(target / "bridge.sqlite")) as db, db:
                db.execute("CREATE TABLE test(value TEXT)")
                db.execute("INSERT INTO test VALUES ('imported')")
            (target / "bridge.sqlite").chmod(0o600)
            for name in ("migration-receipt.json", "migration-report.json"):
                (target / name).write_text(json.dumps({"source": source_id}))
                (target / name).chmod(0o600)
        cutover.regular(target / "migration-receipt.json", self.uid, 0o600)
        return {"source": source_id, **self.import_status}

    def boundary(self, name):
        if name == self.fault:
            if self.kill:
                os.kill(os.getpid(), signal.SIGKILL)
            raise RuntimeError(f"injected {name}")


class RealConverterRuntime(FixtureRuntime):
    def __init__(self, config, fault=None):
        config = {**config, "tools": {**config["tools"], "bwrap": os.environ["CUTOVER_BWRAP"], "converter": os.environ["CUTOVER_CONVERTER"]}}
        super().__init__(config, fault)

    def command(self, argv, user=False, timeout=60, group=None):
        if argv[0] != self.c["tools"]["bwrap"]:
            return super().command(argv, user, timeout, group)
        operation = argv[argv.index("--") + 2]
        if group != (self.c["captureGroup"] if user else None):
            raise AssertionError("Owner conversion must have the private capture group as primary")
        if user != (operation in ("import", "check")):
            raise AssertionError("Only import/check run as ledger owner; inventory/export use capture authority")
        result = subprocess.run(argv, capture_output=True, check=True, timeout=timeout,
                                env={"HOME": self.c["home"], "PATH": "/nonexistent", "TMPDIR": self.c["home"]})
        return result.stdout.decode()

    def converter(self, verb, source, target=None):
        self.converter_calls.append(verb)
        return cutover.Runtime.converter(self, verb, source, target)


class CutoverTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="cutover-173-test-")
        self.root = Path(self.temp.name)
        (self.root / "old").mkdir()
        roots = []
        for role in ("state", "manifests", "native", "account"):
            directory = self.root / "old" / role
            directory.mkdir()
            roots.append({"role": role, "name": role, "original": str(directory)})
        (self.root / "old/state/opaque.json").write_text('{"historical":"not authority"}\n')
        (self.root / "old/state/empty").mkdir()
        (self.root / "old/account/requests.sqlite-journal").write_bytes(b"opaque journal bytes\0")
        (self.root / "old/native/session.jsonl").write_text('{"type":"session","version":3,"id":"native-one","cwd":"' + str(self.root) + '"}\n')
        (self.root / "old/manifests/conv_11111111111111111111111111111111.json").write_text(json.dumps({"conversationId": "conv_11111111111111111111111111111111", "piSessionId": "native-one"}))
        proc = self.root / "proc"
        (proc / "sys/kernel/random").mkdir(parents=True)
        (proc / "sys/kernel/random/boot_id").write_text("synthetic-boot\n")
        (self.root / "cgroups").mkdir()
        self.config = {"version": 1, "id": "native-bridge-172-v1", "host": "fixture", "user": pwd.getpwuid(os.getuid()).pw_name,
                       "home": str(self.root), "state": str(self.root / "new"), "roots": roots,
                       "control": str(self.root / "control"), "runtime": str(self.root / "runtime"), "permit": str(self.root / "permit"),
                       "botUserId": "@bot:example.org", "operatorUserId": "@owner:example.org", "workspaceRoots": [str(self.root)],
                       "startAfterMigration": False, "userConsumers": ["pi-managed-session-relay.service", "pi-managed-session-rollout.service"],
                       "systemConsumers": [], "tools": {"syncthing": "/fixture/syncthing", "git": "/fixture/git"},
                       "testProc": str(proc), "testCgroups": str(self.root / "cgroups"), "syncthingConfig": str(self.root / "syncthing"),
                       "captureGroup": cutover.grp.getgrgid(os.getgid()).gr_name}
        self.r = FixtureRuntime(self.config)
        Path(self.config["permit"]).write_text(self.r.permit_text())
        Path(self.config["permit"]).chmod(0o600)

    def tearDown(self):
        self.temp.cleanup()

    def process(self, pid, name, args=b"", uid=None):
        path = Path(self.config["testProc"]) / str(pid)
        path.mkdir()
        (path / "status").write_text(f"Name:\t{name}\nUid:\t{os.getuid() if uid is None else uid}\t0\t0\t0\n")
        (path / "cmdline").write_bytes(args)
        (path / "exe").symlink_to(f"/fixture/{name}")
        return path

    @contextmanager
    def actual_syncthing(self, paused, status=200):
        requests = []
        # Real API config copies normalize empty maps/slices. An incomplete
        # response can spuriously trigger the CLI editor's write-back branch.
        document = json.loads(Path(__file__).with_name("test-cutover-syncthing-172.json").read_text())
        document["folders"][0]["paused"] = paused
        response = json.dumps(document).encode()
        class Handler(BaseHTTPRequestHandler):
            def do_GET(handler):
                requests.append((handler.command, handler.path))
                if handler.headers.get("X-API-Key") != "synthetic-cutover-test-only":
                    handler.send_error(403)
                    return
                if handler.path != "/rest/system/config":
                    handler.send_error(404)
                    return
                handler.send_response(status)
                handler.send_header("Content-Type", "application/json")
                handler.send_header("Content-Length", str(len(response)))
                handler.end_headers()
                handler.wfile.write(response)
            def do_POST(handler):
                requests.append((handler.command, handler.path))
                handler.send_error(405)  # A read-only query must never write.
            def log_message(handler, *_args):
                pass
        directory = Path(self.config["syncthingConfig"])
        directory.mkdir()
        # The real CLI reads a device certificate even for config GETs. Generate
        # disposable identities here; never copy a real authentication directory.
        executable = os.environ["CUTOVER_SYNCTHING"]
        subprocess.run([executable, "generate", f"--home={directory}"], check=True, capture_output=True, timeout=30,
                       env={"HOME": str(self.root), "PATH": "/nonexistent"})
        with ThreadingHTTPServer(("127.0.0.1", 0), Handler) as server:
            config_file = directory / "config.xml"
            document = ElementTree.parse(config_file)
            gui = document.getroot().find("gui")
            gui.set("enabled", "true")
            gui.set("tls", "false")
            gui.find("address").text = f"127.0.0.1:{server.server_port}"
            gui.find("apikey").text = "synthetic-cutover-test-only"
            document.write(config_file, encoding="utf-8")
            original = {p.relative_to(directory): p.read_bytes() for p in directory.rglob("*") if p.is_file()}
            thread = threading.Thread(target=server.serve_forever)
            thread.start()
            class QueryRuntime(FixtureRuntime):
                def command(runtime, argv, user=False, timeout=60, group=None):
                    if argv[0] == runtime.c["tools"]["syncthing"]:
                        if not user or group is not None:
                            raise AssertionError("Pause inspection must run as the owner")
                        # This test already runs as the disposable fixture owner;
                        # the booted VM separately exercises real root/runuser.
                        return cutover.Runtime.command(runtime, argv, timeout=timeout)
                    return super().command(argv, user, timeout, group)
            config = {**self.config, "tools": {**self.config["tools"], "syncthing": os.environ["CUTOVER_SYNCTHING"]}}
            runtime = QueryRuntime(config)
            Path(config["permit"]).write_text(runtime.permit_text())
            try:
                yield runtime, requests
            finally:
                server.shutdown()
                thread.join()
                try:
                    self.assertEqual({p.relative_to(directory): p.read_bytes() for p in directory.rglob("*") if p.is_file()}, original)
                finally:
                    shutil.rmtree(directory)

    def test_actual_syncthing_cli_confirms_paused_before_stops(self):
        with self.actual_syncthing(True) as (runtime, requests):
            runtime.preflight()
            self.assertTrue(requests)
            self.assertTrue(all(request == ("GET", "/rest/system/config") for request in requests))
            self.assertEqual(runtime.operations, [])
            self.assertFalse((runtime.control / "source").exists())

    def test_actual_syncthing_cli_unpaused_and_http_errors_stay_blocked(self):
        for paused, status in ((False, 200), (True, 403)):
            with self.subTest(paused=paused, status=status):
                with self.actual_syncthing(paused, status) as (runtime, requests):
                    message = "not confirmed paused" if status == 200 else "Required command failed"
                    with self.assertRaisesRegex(cutover.Refused, message):
                        runtime.preflight()
                    self.assertEqual(requests, [("GET", "/rest/system/config")])
                    self.assertEqual(runtime.operations, [])
                    self.assertFalse((runtime.control / "source").exists())

    def test_full_run_preserves_originals_journals_and_empty_dirs(self):
        before = {x["name"]: cutover.tree(x["original"]) for x in self.config["roots"]}
        cutover.run(self.r)
        self.assertEqual(self.r.converter_calls, ["inventory", "export", "import", "check"])
        self.assertTrue((self.r.control / "source/state/empty").is_dir())
        self.assertEqual((self.r.control / "source/account/requests.sqlite-journal").read_bytes(), b"opaque journal bytes\0")
        self.assertEqual(before, {x["name"]: cutover.tree(x["original"]) for x in self.config["roots"]})
        self.assertFalse(cutover.gate(self.r, timeout=0))
        self.assertNotIn(("approved-start",), self.r.operations)
        self.assertEqual(json.loads((self.r.control / "source/source.json").read_text())["currentFiles"], {"native-one": str(self.root / "old/native/session.jsonl")})

    def test_missing_wrong_expired_and_unsafe_permit_have_no_controller_effects(self):
        permit = Path(self.config["permit"])
        for variant in ("wrong", "expired", "permissions", "symlink", "missing"):
            with self.subTest(variant=variant):
                if permit.exists() or permit.is_symlink():
                    permit.unlink()
                permit.write_text(self.r.permit_text())
                permit.chmod(0o600)
                if variant == "wrong": permit.write_text("other\n")
                if variant == "expired": os.utime(permit, (1, 1))
                if variant == "permissions": permit.chmod(0o644)
                if variant == "symlink": permit.unlink(); permit.symlink_to(self.root / "old/state/opaque.json")
                if variant == "missing": permit.unlink()
                with self.assertRaises((cutover.Refused, OSError)):
                    cutover.run(self.r)
                self.assertEqual(self.r.operations, [])
                self.assertFalse((self.r.control / "source").exists())

    def test_source_and_bundle_are_authority_owned_and_frozen_before_use(self):
        original = self.r.converter
        def observing(verb, source, target=None):
            self.r.frozen(source)
            self.assertEqual(source.stat().st_uid, self.r.authority_uid)
            self.assertEqual(source.stat().st_mode & 0o777, 0o550)
            self.assertEqual((source / "source.json").stat().st_mode & 0o777, 0o440)
            return original(verb, source, target)
        self.r.converter = observing
        cutover.run(self.r)
        self.r.frozen(self.r.control / "source")
        self.r.frozen(self.r.control / "bundle")

    def test_unfrozen_published_source_is_not_adopted(self):
        failed = FixtureRuntime(self.config, "capture-after-publish")
        with self.assertRaises(RuntimeError): cutover.run(failed)
        (self.r.control / "source/state/opaque.json").chmod(0o600)
        with self.assertRaisesRegex(cutover.Refused, "not frozen"):
            cutover.run(self.r)
        self.assertEqual(self.r.converter_calls, [])

    def test_unconfirmed_effective_legacy_mask_blocks_capture(self):
        self.r.ineffective_mask = True
        with self.assertRaisesRegex(cutover.Refused, "not masked"):
            cutover.run(self.r)
        self.assertFalse((self.r.control / "source").exists())

    def test_changed_export_identity_is_rejected_before_import(self):
        original = self.r.converter
        def changed(verb, source, target=None):
            value = original(verb, source, target)
            return {**value, "source": "foreign-export"} if verb == "export" else value
        self.r.converter = changed
        with self.assertRaisesRegex(cutover.Refused, "Export differs"):
            cutover.run(self.r)
        self.assertFalse(self.r.state.exists())

    def test_permit_is_bound_to_exact_configuration(self):
        self.r.c["implementation"] = "different implementation"
        with self.assertRaisesRegex(cutover.Refused, "maintenance permit"):
            cutover.run(self.r)
        self.assertEqual(self.r.operations, [])

    def test_concurrent_job_refused_without_withdrawing_readiness(self):
        cutover.run(self.r)
        previous = self.r.ready.read_bytes()
        with (self.r.control / "run.lock").open("rb") as lock:
            cutover.fcntl.flock(lock.fileno(), cutover.fcntl.LOCK_EX | cutover.fcntl.LOCK_NB)
            with self.assertRaisesRegex(cutover.Refused, "Another cutover"):
                cutover.run(self.r)
        self.assertEqual(self.r.ready.read_bytes(), previous)

    def test_failed_revalidation_withdraws_old_runtime_readiness(self):
        cutover.run(self.r)
        ledger = self.r.state / "bridge.sqlite"
        ledger.rename(self.r.state / "retained-original.sqlite")
        ledger.write_bytes(b"SQLite format 3\0foreign")
        ledger.chmod(0o600)
        with self.assertRaisesRegex(cutover.Refused, "identity changed"):
            cutover.run(self.r)
        self.assertFalse(self.r.ready.exists())
        self.r.c["startAfterMigration"] = True
        self.assertFalse(cutover.gate(self.r, timeout=0))

    def test_live_pi_and_finite_creators_block_without_killing(self):
        for name, args in [("pi", b""), ("git", b""), ("direnv", b""), ("tmux_project", b""), ("python3", b"python3\0/store/task-git.py\0"), ("MainThread", b"node\0/store/task-worker.js\0")]:
            with self.subTest(name=name):
                path = self.process(101, name, args)
                with self.assertRaisesRegex(cutover.Refused, "activity remains"):
                    cutover.run(self.r)
                self.assertTrue(path.exists())
                self.assertEqual(self.r.operations, [])
                shutil.rmtree(path)

    def test_pi_executable_with_generic_comm_still_blocks(self):
        path = self.process(101, "MainThread", b"/store/pi\0")
        (path / "exe").unlink(); (path / "exe").symlink_to("/nix/store/fixture/libexec/pi/pi")
        with self.assertRaisesRegex(cutover.Refused, "activity remains"):
            cutover.run(self.r)
        self.assertEqual(self.r.operations, [])

    def test_nas_stops_only_named_consumers_and_never_masks_new_units(self):
        self.config["systemConsumers"] = ["pi-chat-transport.service", "pi-chat-model.service"]
        self.r = FixtureRuntime(self.config)
        for unit in self.config["systemConsumers"]:
            self.r.units[unit] = {"ActiveState": "active", "MainPID": "10", "ControlGroup": ""}
        Path(self.config["permit"]).write_text(self.r.permit_text())
        cutover.run(self.r)
        self.assertIn((False, "stop", "pi-chat-transport.service", "pi-chat-model.service"), self.r.operations)
        self.assertFalse(any(op[0] is False and op[1] == "mask" for op in self.r.operations))
        self.assertFalse(any("tmux-shared.service" in op for op in self.r.operations))

    def test_inflight_cleanup_blocks_nas_capture(self):
        self.config["systemConsumers"] = ["pi-chat-transport.service", "pi-chat-model.service"]
        self.r = FixtureRuntime(self.config)
        self.r.units["systemd-tmpfiles-clean.service"] = {"ActiveState": "active", "MainPID": "30"}
        Path(self.config["permit"]).write_text(self.r.permit_text())
        with self.assertRaisesRegex(cutover.Refused, "tmpfiles"):
            cutover.run(self.r)
        self.assertFalse((self.r.control / "source").exists())

    def test_unpaused_or_unknown_sync_blocks_before_stops(self):
        for value in ("false", "", "unknown"):
            self.r.paused = value
            with self.assertRaisesRegex(cutover.Refused, "state-sync"):
                cutover.run(self.r)
            self.assertEqual(self.r.operations, [])

    def test_unknown_process_evidence_blocks(self):
        path = self.process(101, "pi")
        (path / "status").write_text("Name: pi\n")
        with self.assertRaisesRegex(cutover.Refused, "Unreadable"):
            cutover.run(self.r)

    def test_already_running_new_bridge_blocks(self):
        self.r.units["pi-matrix-bridge.service"] = {"MainPID": "101"}
        with self.assertRaisesRegex(cutover.Refused, "already running"):
            cutover.run(self.r)
        self.assertEqual(self.r.operations, [])

    def test_consumer_descendants_need_completion_except_exact_lock_helper(self):
        group = Path(self.config["testCgroups"]) / "old-relay"
        group.mkdir(); (group / "cgroup.procs").write_text("10\n11\n")
        self.r.units["pi-managed-session-relay.service"] = {"ActiveState": "active", "MainPID": "10", "ControlGroup": "/old-relay"}
        main = self.process(10, "MainThread", b"node\0/relay.js\0")
        child = self.process(11, "helper")
        (child / "exe").unlink()
        (child / "exe").symlink_to("/nix/store/fixture/bin/unknown-helper")
        with self.assertRaisesRegex(cutover.Refused, "live helper"):
            cutover.run(self.r)
        self.assertEqual(self.r.operations, [])
        (child / "exe").unlink(); (child / "exe").symlink_to("/nix/store/fixture/bin/pi-managed-session-relay-lock")
        cutover.run(self.r)
        self.assertTrue(main.exists())  # Fixture stop never signals a process.
        self.assertTrue(any(op[1] == "mask" for op in self.r.operations))

    def test_consumer_control_ack_without_exit_blocks_capture(self):
        self.r.exited = False
        with self.assertRaisesRegex(cutover.Refused, "has not exited"):
            cutover.run(self.r)
        self.assertFalse((self.r.control / "source").exists())

    def test_real_pidfd_distinguishes_owned_fixture_exit_from_presence(self):
        with subprocess.Popen([sys.executable, "-c", "import time; time.sleep(30)"], stdin=subprocess.DEVNULL) as child:
            try:
                with cutover.Runtime.exit_barrier(self.r, {child.pid}) as verify:
                    with self.assertRaisesRegex(cutover.Refused, "has not exited"):
                        verify()
                    child.terminate(); child.wait(timeout=5)
                    verify()
            finally:
                if child.poll() is None:
                    child.kill(); child.wait(timeout=5)

    def test_approved_start_calls_only_replacement_consumers(self):
        self.r.c["startAfterMigration"] = True
        self.r.c["systemConsumers"] = ["pi-chat-transport.service", "pi-chat-model.service"]
        self.r.user_manager_present = lambda: True
        cutover.Runtime.start_consumers(self.r)
        self.assertEqual(self.r.operations, [
            (False, "start", "--no-block", "pi-chat-transport.service", "pi-chat-model.service"),
            (True, "daemon-reload"), (True, "start", "--no-block", "pi-matrix-bridge.service")])

    def test_symlink_and_special_source_files_refused(self):
        path = self.root / "old/state/unsafe"
        for kind in ("symlink", "fifo"):
            with self.subTest(kind=kind):
                if kind == "symlink": path.symlink_to(self.root / "old/account/requests.sqlite-journal")
                else: os.mkfifo(path)
                with self.assertRaises(cutover.Refused):
                    cutover.run(self.r)
                self.assertFalse((self.r.control / "source").exists())
                self.assertFalse(self.r.state.exists())
                path.unlink()

    def test_foreign_destination_is_never_overwritten(self):
        self.r.state.mkdir(mode=0o700)
        (self.r.state / "foreign").write_bytes(b"keep")
        with self.assertRaises(OSError): cutover.run(self.r)
        self.assertEqual((self.r.state / "foreign").read_bytes(), b"keep")
        self.assertFalse(self.r.completion.exists())

    def test_changed_original_after_capture_blocks_retry(self):
        failed = FixtureRuntime(self.config, "capture-after-publish")
        with self.assertRaises(RuntimeError): cutover.run(failed)
        (self.root / "old/state/new-input.json").write_text("new input evidence")
        with self.assertRaisesRegex(cutover.Refused, "changed since capture"):
            cutover.run(self.r)
        self.assertEqual(self.r.converter_calls, [])

    def test_started_changed_or_native_changed_import_does_not_complete(self):
        for field, value in (("started", True), ("pristine", False), ("nativeUnchanged", False)):
            with self.subTest(field=field):
                self.r.import_status[field] = value
                with self.assertRaisesRegex(cutover.Refused, "not pristine"):
                    cutover.run(self.r)
                self.assertFalse(self.r.completion.exists())
                self.r.import_status[field] = not value

    def test_completed_rebuild_does_not_read_old_roots_or_reimport_used_ledger(self):
        cutover.run(self.r)
        with closing(sqlite3.connect(self.r.state / "bridge.sqlite")) as db, db:
            db.execute("INSERT INTO test VALUES ('new legitimate work')")
        shutil.rmtree(self.root / "old")
        (self.r.control / "bundle").rename(self.r.control / "retained-bundle")
        (self.r.control / "source").rename(self.r.control / "retained-source")
        Path(self.config["permit"]).unlink()
        second = FixtureRuntime({**self.config, "startAfterMigration": True})
        cutover.run(second)
        self.assertEqual(second.converter_calls, [])
        self.assertEqual(second.operations, [("approved-start",)])
        self.assertTrue(cutover.gate(second, timeout=0, native=True))

    def test_replaced_destination_receipt_or_symlink_blocks_completed_rebuild(self):
        cutover.run(self.r)
        receipt = self.r.state / "migration-receipt.json"
        receipt.write_text("foreign")
        with self.assertRaisesRegex(cutover.Refused, "identity changed"):
            cutover.run(self.r)
        self.assertEqual(self.r.converter_calls, ["inventory", "export", "import", "check"])

    def test_unpublished_capture_retained_and_retry_uses_new_staging(self):
        failed = FixtureRuntime(self.config, "capture-before-publish")
        with self.assertRaises(RuntimeError): cutover.run(failed)
        partials = list(self.r.control.glob(".source-partial-*"))
        self.assertEqual(len(partials), 1)
        cutover.run(self.r)
        self.assertTrue(partials[0].is_dir())

    def test_no_replace_publication_preserves_foreign_directory(self):
        (self.root / "partial").mkdir(); (self.root / "foreign").mkdir()
        (self.root / "foreign/keep").write_bytes(b"keep")
        with self.assertRaises(OSError): cutover.publish(self.root, "partial", "foreign")
        self.assertTrue((self.root / "partial").exists())
        self.assertEqual((self.root / "foreign/keep").read_bytes(), b"keep")

    def test_gate_requires_current_boot_readiness_and_explicit_startup(self):
        cutover.run(self.r)
        self.assertFalse(cutover.gate(self.r, timeout=0, native=True))
        self.r.c["startAfterMigration"] = True
        self.assertTrue(cutover.gate(self.r, timeout=0, native=True))
        (self.r.proc / "sys/kernel/random/boot_id").write_text("new boot\n")
        with self.assertRaisesRegex(cutover.Refused, "readiness identity"):
            cutover.gate(self.r, timeout=0)
        cutover.run(self.r)
        self.assertTrue(cutover.gate(self.r, timeout=0))

    def test_sandboxed_nas_gate_does_not_need_home_or_ledger_access(self):
        cutover.run(self.r)
        self.r.c["startAfterMigration"] = True
        def inaccessible(): raise PermissionError("ProtectHome")
        self.r.destination_identity = inaccessible
        self.assertTrue(cutover.gate(self.r, timeout=0))
        with self.assertRaises(PermissionError): cutover.gate(self.r, timeout=0, native=True)

    def test_gate_without_readiness_never_runs_converter_or_control_mutations(self):
        self.r.c["startAfterMigration"] = True
        self.assertFalse(cutover.gate(self.r, timeout=0))
        self.assertEqual(self.r.operations, [])
        self.assertEqual(self.r.converter_calls, [])

    def test_sigkill_import_and_completion_boundaries(self):
        config_path = self.root / "test-config.json"
        config_path.write_text(json.dumps(self.config))
        for point in ("import-complete", "completion-after-publish"):
            with self.subTest(point=point):
                result = subprocess.run([sys.executable, __file__, "--crash", str(config_path), point], capture_output=True, timeout=30)
                self.assertEqual(result.returncode, -signal.SIGKILL, result.stderr.decode())
                before = (self.r.state / "bridge.sqlite").read_bytes()
                cutover.run(self.r)
                self.assertEqual((self.r.state / "bridge.sqlite").read_bytes(), before)
                if point == "import-complete":
                    self.r.completion.unlink(); self.r.ready.unlink()

    def test_actual_converter_with_readonly_namespaces(self):
        # Explicit opt-in check runner supplies immutable tool/fixture paths;
        # omission is a failure, never a silent skipped production-path test.
        fixture = Path(os.environ["CUTOVER_FIXTURE"])
        for role in ("state", "manifests", "native", "account"):
            target = self.root / "old" / role
            shutil.rmtree(target)
            shutil.copytree(fixture / role, target)
        source = json.loads((fixture / "source.json").read_text())
        self.config.update(host=source["hostId"], botUserId=source["botUserId"], operatorUserId=source["operatorUserId"])
        real = RealConverterRuntime(self.config)
        Path(self.config["permit"]).write_text(real.permit_text())
        original = {r["name"]: cutover.tree(r["original"]) for r in self.config["roots"]}
        real.fault = "import-complete"
        with self.assertRaises(RuntimeError):
            cutover.run(real)
        imported = (real.state / "bridge.sqlite").read_bytes()
        self.assertFalse(real.completion.exists())
        real.fault = None
        cutover.run(real)
        self.assertEqual((real.state / "bridge.sqlite").read_bytes(), imported)
        self.assertEqual(real.converter_calls, ["inventory", "export", "import", "inventory", "export", "import", "check"])
        self.assertEqual(original, {r["name"]: cutover.tree(r["original"]) for r in self.config["roots"]})
        self.assertFalse((real.state / "bridge.sqlite-wal").exists())
        self.assertFalse((real.state / "bridge.sqlite-shm").exists())
        receipt = json.loads((real.state / "migration-receipt.json").read_text())
        self.assertEqual(real.completed()["source"], receipt["source"])


if __name__ == "__main__":
    if len(sys.argv) == 4 and sys.argv[1] == "--crash":
        cutover.run(FixtureRuntime(json.loads(Path(sys.argv[2]).read_text()), sys.argv[3], True))
    else:
        unittest.main()
