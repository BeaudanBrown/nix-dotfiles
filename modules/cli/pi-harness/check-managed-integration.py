"""Source-only #120 checks. No Nix evaluation, secret reads or live endpoints."""
import argparse
import json
from pathlib import Path
import re
import unittest

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--harness-source", required=True, type=Path)
args, remaining = parser.parse_known_args()
ROOT = Path(__file__).resolve().parents[3]
HARNESS = args.harness_source


def source(path):
    return (ROOT / path).read_text()


class ManagedIntegration(unittest.TestCase):
    def test_exact_recipient_and_bot_devices(self):
        matrix = source("modules/services/matrix/nas.nix")
        block = matrix.split("managedAccountHosts = [", 1)[1].split("];", 1)[0]
        triples = re.findall(
            r'hostId = "([^"]+)";\s+botUserId = "([^"]+)";\s+deviceId = "([^"]+)";', block
        )
        self.assertEqual(triples, [
            ("grill", "@pi-grill:matrix.bepis.lol", "PI_GRILL_RELAY"),
            ("nas", "@pi-nas:matrix.bepis.lol", "LKVMVRCIUY"),
        ])
        self.assertNotIn('"*"', block)
        for host in ("grill", "nas"):
            text = source(f"modules/cli/pi-harness/{host}.nix")
            self.assertIn('accountDeviceId = "PXZRSYBGDY";', text)
            self.assertIn('operatorUserId = "@beau:matrix.bepis.lol";', text)
            self.assertIn(f'botUserId = "@pi-{host}:matrix.bepis.lol";', text)
            self.assertIn(f'hostId = "{host}";', text)
            self.assertNotIn('pi-chat/matrix-token', text)

    def test_existing_assistant_and_file_grants(self):
        matrix = source("modules/services/matrix/nas.nix")
        for line in (
            'matrixTokenFile = config.sops.secrets."pi-chat/matrix-token".path;',
            'roomIds = [ "!XljGtOqHxkwHiILSto:matrix.bepis.lol" ];',
            'allJoinedRooms = false;', 'remoteOwnerUserIds = [ ];',
            'model = "gpt-5.6-terra";', 'ownerUserId = userId;',
        ):
            self.assertIn(line, matrix)
        self.assertIn('files.enable = true;', source("modules/hosted-services/dump/nas.nix"))
        bridge = (HARNESS / "nix/bridge-chat.nix").read_text()
        model = bridge.split('systemd.services.pi-chat-model =', 1)[1].split('systemd.services.pi-chat-transport =', 1)[0]
        self.assertNotIn('matrixTokenFile', model)
        self.assertIn('LoadCredential', bridge)

    def test_experiment_and_local_only_separation(self):
        network = source("modules/cli/pi-harness/network.nix")
        self.assertIn('experiments.piR.enable = false;', network)
        self.assertIn('experiments.agentgraph.enable = false;', network)
        self.assertIn('name = "pi-local";', network)
        self.assertIn('exec ${piHarnessPackage}/bin/pi-r-local', network)
        self.assertNotIn('name = "pi-local-only";', network)
        module = (HARNESS / "nix/module.nix").read_text()
        self.assertIn('pkgs.writeShellScriptBin "pi-local-only"', module)
        self.assertIn('lib.optional managedSessionsEnabled localOnlyPi', module)

    def test_central_policy_unchanged(self):
        policy = json.loads((HARNESS / "config/agent/managed-host-policy.json").read_text())
        self.assertEqual(policy['version'], '1.0.0')
        for operation, rules in policy['actions'].items():
            read = operation.endswith(('.list', '.status', '.preview'))
            self.assertEqual(rules['model'], 'direct' if read else 'approval', operation)
        for host in ("grill", "nas"):
            text = source(f"modules/cli/pi-harness/{host}.nix")
            self.assertRegex(text, r'actionPolicyOverrides\s*=\s*\{\s*\};')
            self.assertIn('retainRuntime = true;', text)
            self.assertIn('NoNewPrivileges = lib.mkForce false;', text)

    def test_roots_shared_ownership_and_keybinding(self):
        grill = source("modules/cli/pi-harness/grill.nix")
        nas = source("modules/cli/pi-harness/nas.nix")
        self.assertIn('workspaceRoot = "${config.hostSpec.home}/documents/projects";', grill)
        self.assertIn('documents = "${config.hostSpec.home}/documents";', grill)
        self.assertIn('workspaceRoots.projects = "${config.hostSpec.home}/documents/projects";', nas)
        for text in (grill, nas):
            self.assertIn('import ../tmux/tmux_project.nix', text)
        tmux = source("modules/cli/tmux/common.nix")
        self.assertIn('import ./tmux_project.nix', tmux)
        self.assertIn('launcher-popup \'#{client_name}\'', tmux)
        shared = source("modules/cli/tmux/shared-server.nix")
        for line in ('managedSessions.updateGuard = guard;', 'restartIfChanged = false;', 'stopIfChanged = false;'):
            self.assertIn(line, shared)

    def test_selected_revision_is_explicitly_staged(self):
        revision = '99f59415a6564afe23a454244da7726b2b68a43f'
        self.assertIn('github:BeaudanBrown/pi-harness/' + revision, source('flake.nix'))
        locked = json.loads(source('flake.lock'))['nodes']['pi-harness']['locked']['rev']
        # Intentional outstanding publication/lock boundary, not a valid build claim.
        self.assertIn(locked, ('1604a971d5990e520399186de7dd90a7071dca65', revision))
        if locked != revision:
            self.assertIn('not presently a resolved', source('specs/managed-live-workspaces.md'))

    def test_package_checks_have_real_ui_dependencies(self):
        package = source('modules/cli/tmux/tmux_project.nix')
        self.assertIn('versionAtLeast pkgs.tmux.version "3.6"', package)
        self.assertIn('versionAtLeast pkgs.fzf.version "0.70"', package)
        checks = package.split('nativeCheckInputs = [', 1)[1].split('];', 1)[0]
        for item in ('pkgs.git', 'pkgs.tmux.rawTmux or pkgs.tmux', 'pkgs.fzf', 'pkgs.fd', 'pkgs.python3'):
            self.assertIn(item, checks)
        self.assertIn('PI_TEST_FZF = "${pkgs.fzf}/bin/fzf";', package)


if __name__ == '__main__':
    unittest.main(argv=[__file__, *remaining])
