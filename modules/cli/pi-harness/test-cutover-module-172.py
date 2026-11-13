"""Evaluate the temporary adapter without realizing/building any Nix output."""
import argparse
import json
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--base", default="github:BeaudanBrown/nix-dotfiles/8bdcf0a7bda03ce1d4ab3ba753ea20a417b755a6")
parser.add_argument("--output", type=Path)
args = parser.parse_args()
module = Path(__file__).resolve().with_name("cutover-172.nix")
base = json.dumps(args.base).replace("${", "\\${")
module_literal = json.dumps(str(module)).replace("${", "\\${")
expression = r'''let
  f = builtins.getFlake BASE;
  examine = host: enabled: start:
    let
      base = f.nixosConfigurations.${host};
      modules = (if base.options.services ? piNativeCutover172 then [] else [ (builtins.toPath MODULE) ])
        ++ [ ({ lib, ... }: { services.piNativeCutover172 = {
          enable = lib.mkForce enabled;
          startAfterMigration = lib.mkForce start;
          holdSynchronization = lib.mkForce (!start);
        }; }) ];
      c = (base.extendModules { inherit modules; }).config;
      s = c.systemd.services;
      u = c.systemd.user.services;
    in {
      inherit host enabled start;
      failed = map (a: a.message) (builtins.filter (a: !a.assertion) c.assertions);
      system = if enabled then c.system.build.toplevel.drvPath else null;
      job = if enabled then s.pi-native-cutover-172.serviceConfig else null;
      jobPresent = s ? pi-native-cutover-172;
      captureReaders = if enabled then c.users.groups.pi-native-cutover-172.members else [];
      jobAfter = if enabled then s.pi-native-cutover-172.after else [];
      jobRequiresMounts = if enabled then s.pi-native-cutover-172.unitConfig.RequiresMountsFor else [];
      bridge = u.pi-matrix-bridge.serviceConfig;
      piVersion = c.services.pi-harness.package.pi.version;
      bridgeCondition = u.pi-matrix-bridge.unitConfig.ConditionPathExists or null;
      bridgeRequires = u.pi-matrix-bridge.requires;
      syncPaused = c.services.syncthing.settings.folders.state-sync.paused or false;
      legacyMasks = if enabled then map (name: c.systemd.user.units.${name}.enable) [ "pi-managed-session-relay.service" "pi-managed-session-rollout.service" ] else [];
      legacyUnitsAbsent = !(u ? pi-managed-session-relay) && !(u ? pi-managed-session-rollout);
      sharedRestart = u.tmux-shared.restartIfChanged;
      sharedStop = u.tmux-shared.stopIfChanged;
      model = if host == "nas" then s.pi-chat-model.serviceConfig else null;
      modelCondition = if host == "nas" then s.pi-chat-model.unitConfig.ConditionPathExists or null else null;
      transport = if host == "nas" then s.pi-chat-transport.serviceConfig else null;
      transportCondition = if host == "nas" then s.pi-chat-transport.unitConfig.ConditionPathExists or null else null;
    };
in builtins.concatMap (host: [ (examine host false false) (examine host true false) (examine host true true) ]) [ "grill" "nas" ]
'''.replace("BASE", base).replace("MODULE", module_literal)
result = subprocess.run(["nix", "eval", "--impure", "--json", "--expr", expression], capture_output=True, text=True, check=False)
if result.returncode:
    print(result.stderr)
    raise SystemExit(result.returncode)
values = json.loads(result.stdout)
for value in values:
    assert value["failed"] == [], value["failed"]
    assert value["bridgeRequires"] == []
    assert value["piVersion"] == "0.84.4"
    assert value["legacyUnitsAbsent"] is True
    assert value["sharedRestart"] is False and value["sharedStop"] is False
    if not value["enabled"]:
        assert value["jobPresent"] is False
        assert value["bridge"].get("ExecCondition", []) == []
        assert value["bridgeCondition"] is None
        continue
    assert value["job"]["Type"] == "oneshot" and value["job"]["Restart"] == "no"
    assert value["job"]["RemainAfterExit"] is True
    assert value["job"]["StateDirectoryMode"] == "0755"
    assert value["job"].get("User", "root") == "root"
    assert value["captureReaders"] == ["beau"]
    assert "user@1000.service" in value["jobAfter"]
    assert len(value["bridge"]["ExecCondition"]) == 1 and value["bridge"]["ExecCondition"][0].endswith(" gate-native")
    condition = "/run/pi-native-cutover-172/ready.json" if value["start"] else "!/"
    assert value["bridgeCondition"] == condition
    assert value["legacyMasks"] == [False, False]
    if not value["start"]:
        assert value["syncPaused"] is True
    if value["host"] == "nas":
        for key in ("model", "transport"):
            assert value[key]["ExecCondition"][0].endswith(" gate")
            assert value[key + "Condition"] == condition
    print(f"{value['host']}: start={value['start']}; assertions, startup/ownership guards and full system derivation evaluated")
assert len(values) == 6
if args.output:
    args.output.write_text(json.dumps(values, indent=2) + "\n")
print("Six configuration variants passed; no build, activation or live service effect")
