"""Native Matrix–Pi source contracts; --evaluate adds NixOS evaluation, never builds/activation."""
import argparse
import json
from pathlib import Path
import subprocess
import unittest

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--harness-source", required=True, type=Path)
parser.add_argument("--evaluate", action="store_true")
args, remaining = parser.parse_known_args()
ROOT = Path(__file__).resolve().parents[3]
HARNESS = args.harness_source.resolve()


def source(path):
    return (ROOT / path).read_text()


class NativeIntegration(unittest.TestCase):
    def test_host_contract_and_independent_lifetimes(self):
        for host in ("grill", "nas"):
            text = source(f"modules/cli/pi-harness/{host}.nix")
            self.assertIn("services.pi-harness.matrixBridge =", text)
            self.assertNotIn("managedSessions", text)
            self.assertIn(f'botUserId = "@pi-{host}:matrix.bepis.lol";', text)
            self.assertIn('operatorUserId = "@beau:matrix.bepis.lol";', text)
            self.assertIn("retainRuntime = true;", text)
            self.assertIn("import ../tmux/tmux_project.nix", text)
            self.assertIn("%h/.pi/agent/sessions", text)
            self.assertIn("%h/.local/state/pi-managed-sessions/project-sessions", text)
            self.assertNotIn("pi-chat/matrix-token", text)
        shared = source("modules/cli/tmux/shared-server.nix")
        self.assertIn("restartIfChanged = false;", shared)
        self.assertIn("stopIfChanged = false;", shared)
        self.assertNotIn("managedSessions", shared)
        client = source("modules/cli/tmux/shared-client.sh")
        self.assertIn("-N", client)

    def test_picker_has_no_managed_protocol_or_private_database_dependency(self):
        for path in (ROOT / "modules/cli/tmux/tmux-project-go").glob("picker*.go"):
            if path.name.endswith("_test.go"):
                continue
            text = path.read_text()
            for forbidden in ("host-control", "pi-managed-session", "coordinator", "sqlite", "generationId"):
                self.assertNotIn(forbidden, text, str(path))
        native = source("modules/cli/tmux/tmux-project-go/picker_native.go")
        self.assertIn('"pi-session"', native)
        self.assertIn('"--expected-id"', native)
        self.assertIn('"--all"', native)
        window = source("modules/cli/tmux/tmux-project-go/native_window.go")
        self.assertIn("DisallowUnknownFields", window)
        self.assertNotIn("managed(", window)
        main = source("modules/cli/tmux/tmux-project-go/main.go")
        self.assertNotIn('case "managed":', main)
        self.assertFalse(list((ROOT / "modules/cli/tmux/tmux-project-go").glob("managed*.go")))

    def test_central_profile_experiments_and_tested_pi_pin(self):
        network = source("modules/cli/pi-harness/network.nix")
        self.assertIn("experiments.piR.enable = false;", network)
        self.assertIn("experiments.agentgraph.enable = false;", network)
        self.assertIn("exec ${piHarnessPackage}/bin/pi-r-local", network)
        profiles = json.loads((HARNESS / "config/agent/profiles.json").read_text())
        self.assertIn("matrix-bridge", profiles["profiles"]["engineering-full"]["extensions"])
        self.assertNotIn("bridge-engineering", profiles["profiles"])
        block = source("flake.nix").split("    pi-harness = {", 1)[1].split("    };", 1)[0]
        self.assertNotIn("inputs.nix-ai-tools.follows", block)

    def test_narrow_owner_invitations_replace_managed_account_policy(self):
        matrix = source("modules/services/matrix/nas.nix")
        block = matrix.split("trustedBridgeBots = {", 1)[1].split("};", 1)[0]
        self.assertIn('grill = "@pi-grill:matrix.bepis.lol";', block)
        self.assertIn('nas = "@pi-nas:matrix.bepis.lol";', block)
        self.assertNotIn("managedAccountHosts", matrix)
        self.assertIn('matrixTokenFile = config.sops.secrets."pi-chat/matrix-token".path;', matrix)
        self.assertIn("allJoinedRooms = false;", matrix)

    def test_real_ui_dependencies_remain_packaged(self):
        package = source("modules/cli/tmux/tmux_project.nix")
        for text in ('versionAtLeast pkgs.tmux.version "3.6"', 'versionAtLeast pkgs.fzf.version "0.70"',
                     "pkgs.tmux.rawTmux or pkgs.tmux", "pkgs.fzf", "pkgs.fd", "pkgs.python3"):
            self.assertIn(text, package)


if args.evaluate:
    class NativeHostEvaluation(unittest.TestCase):
        def test_both_hosts(self):
            expression = '''c: let unit = c.systemd.user.services.pi-matrix-bridge; in {
              bridge = c.services.pi-harness.matrixBridge.enable;
              legacyOptionAbsent = !(c.services.pi-harness ? managedSessions);
              legacyUnitsAbsent = !(c.systemd.user.services ? pi-managed-session-relay) && !(c.systemd.user.services ? pi-managed-session-rollout);
              piVersion = c.services.pi-harness.package.pi.version;
              retainRuntime = c.services.pi-harness.matrixBridge.retainRuntime;
              invitationHosts = c.services.pi-harness.bridgeChat.assistant.trustedBridgeBots;
              legacyAccountOptionAbsent = !(c.services.pi-harness.bridgeChat.assistant ? managedAccountHosts);
              service = unit.serviceConfig;
              dependencies = unit.requires ++ unit.bindsTo ++ unit.partOf;
              sharedRestart = c.systemd.user.services.tmux-shared.restartIfChanged;
              sharedStop = c.systemd.user.services.tmux-shared.stopIfChanged;
              failedAssertions = builtins.map (a: a.message) (builtins.filter (a: !a.assertion) c.assertions);
            }'''
            for host in ("grill", "nas"):
                with self.subTest(host=host):
                    result = subprocess.run([
                        "nix", "eval", "--json", f"{ROOT}#nixosConfigurations.{host}.config",
                        "--override-input", "pi-harness", f"git+file://{HARNESS}",
                        "--no-write-lock-file", "--apply", expression,
                    ], capture_output=True, text=True, timeout=180)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    view = json.loads(result.stdout)
                    self.assertTrue(view["bridge"])
                    self.assertTrue(view["legacyOptionAbsent"])
                    self.assertTrue(view["legacyUnitsAbsent"])
                    self.assertEqual(view["piVersion"], "0.84.4")
                    self.assertTrue(view["retainRuntime"])
                    self.assertTrue(view["legacyAccountOptionAbsent"])
                    self.assertEqual(view["invitationHosts"], {
                        "grill": "@pi-grill:matrix.bepis.lol", "nas": "@pi-nas:matrix.bepis.lol",
                    } if host == "nas" else {})
                    self.assertEqual(view["dependencies"], [])
                    self.assertFalse(view["sharedRestart"])
                    self.assertFalse(view["sharedStop"])
                    self.assertEqual(view["failedAssertions"], [])
                    service = view["service"]
                    self.assertEqual(service["KillMode"], "process")
                    self.assertFalse(service["NoNewPrivileges"])
                    self.assertEqual(service["LoadCredential"], [f"matrix-token:/run/secrets/pi/matrix-{host}-env"])
                    self.assertNotIn("EnvironmentFile", service)
                    self.assertIn("--credential-file %d/matrix-token", service["ExecStart"])
                    print(f"{host}: Pi {view['piVersion']}, native bridge only, independent lifetimes, assertions pass")


if __name__ == "__main__":
    unittest.main(argv=[__file__, *remaining])
