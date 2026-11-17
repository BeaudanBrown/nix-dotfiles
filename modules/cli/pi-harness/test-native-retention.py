"""Evaluate normal grill/NAS startup without realizing or activating outputs."""
import json
from pathlib import Path
import subprocess

repo = Path(__file__).resolve().parents[3]
expression = '''c: let summarize = s: { inherit (s) wantedBy wants partOf bindsTo serviceConfig unitConfig; }; in {
  system = c.system.build.toplevel.outPath;
  drv = c.system.build.toplevel.drvPath;
  migrationAbsent = !(c.systemd.services ? pi-native-cutover-172);
  packages = map (p: p.name or "") c.environment.systemPackages;
  paused = c.services.syncthing.settings.folders.state-sync.paused;
  masks = map (n: c.systemd.user.units.${n}.enable) [ "pi-managed-session-relay.service" "pi-managed-session-rollout.service" ];
  captureMembers = c.users.groups.pi-native-cutover-172.members;
  tmpfiles = c.systemd.tmpfiles.rules;
  bridge = summarize c.systemd.user.services.pi-matrix-bridge;
  model = if c.systemd.services ? pi-chat-model then summarize c.systemd.services.pi-chat-model else null;
  transport = if c.systemd.services ? pi-chat-transport then summarize c.systemd.services.pi-chat-transport else null;
  projectRoot = c.services.pi-harness.matrixBridge.projectRoot;
  roots = c.services.pi-harness.matrixBridge.roots;
  harnessRevision = c.services.pi-harness.package.evalLauncherIdentity.harnessRevision;
  assertions = map (a: a.assertion) c.assertions;
}'''

def evaluate(host):
    value = json.loads(subprocess.check_output([
        'nix', 'eval', '--json', '--no-write-lock-file',
        f'git+file://{repo}#nixosConfigurations.{host}.config', '--apply', expression
    ], text=True))
    assert all(value.pop('assertions'))
    assert value['migrationAbsent'] and value['paused']
    assert value['masks'] == [False, False]
    assert value['captureMembers'] == ['beau']
    assert not any('pi-native-cutover-172' in p for p in value['packages'])
    assert value['harnessRevision'] == '21f9a4b4db9a90518d5e173e53cbae2b407daa6f'
    assert value['projectRoot'] == '/home/beau/documents/projects'
    assert value['roots'] == (['/home/beau/documents/projects', '/home/beau/documents', '/home/beau/collab'] if host == 'grill' else ['/home/beau/documents/projects'])
    for service in [value['bridge'], value['model'], value['transport']]:
        if service is None:
            continue
        assert 'pi-native-cutover-172' not in json.dumps(service)
        assert not service['serviceConfig'].get('ExecCondition')
    bridge = value['bridge']
    assert bridge['wantedBy'] == ['default.target']
    assert not bridge.get('partOf') and not bridge.get('bindsTo')
    assert bridge['serviceConfig']['KillMode'] == 'process'
    if host == 'nas':
        assert 'x /var/lib/pi-chat-files - - - -' in value['tmpfiles']
        assert value['transport']['wantedBy'] == ['multi-user.target']
        assert 'pi-chat-model.service' in value['transport']['wants']
    return value

if __name__ == '__main__':
    print(json.dumps({host: evaluate(host) for host in ['grill', 'nas']}, indent=2))
