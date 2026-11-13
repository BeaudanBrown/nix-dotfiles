# Temporary deployment adapter for #172, not a Pi/session lifecycle manager.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.piNativeCutover172;
  bridge = config.services.pi-harness.matrixBridge;
  user = config.hostSpec.username;
  home = config.hostSpec.home;
  host = config.networking.hostName;
  nas = host == "nas";
  legacy = "${home}/.local/state/pi-managed-sessions";
  roots = [
    {
      role = "state";
      name = "state";
      original = "${legacy}/relay";
    }
    {
      role = "manifests";
      name = "manifests";
      original = "${legacy}/manifests";
    }
    {
      role = "native";
      name = "project";
      original = "${legacy}/project-sessions";
    }
    {
      role = "native";
      name = "coordinator";
      original = "${legacy}/coordinator";
    }
    {
      role = "native";
      name = "ordinary";
      original = "${home}/.pi/agent/sessions";
    }
  ]
  ++ lib.optionals nas [
    {
      role = "account";
      name = "account";
      original = "/var/lib/private/pi-chat-transport";
    }
    {
      role = "account";
      name = "model";
      original = "/var/lib/pi-chat-model";
    }
    {
      role = "account";
      name = "files";
      original = "/var/lib/pi-chat-files";
    }
  ];
  userConsumers = [
    "pi-managed-session-relay.service"
    "pi-managed-session-rollout.service"
  ];
  systemConsumers = lib.optionals nas [
    "pi-chat-transport.service"
    "pi-chat-model.service"
  ];
  settings = pkgs.writeText "pi-native-cutover-172.json" (
    builtins.toJSON {
      version = 1;
      id = "native-bridge-172-v1";
      inherit
        host
        user
        home
        roots
        userConsumers
        systemConsumers
        ;
      inherit (cfg) startAfterMigration holdSynchronization;
      implementation = builtins.hashFile "sha256" ./cutover-172.py;
      inherit (bridge) botUserId operatorUserId;
      workspaceRoots = bridge.roots;
      syncthingConfig = config.services.syncthing.configDir;
      state = lib.replaceStrings [ "%h" ] [ home ] bridge.stateDirectory;
      captureGroup = "pi-native-cutover-172";
      control = "/var/lib/pi-native-cutover-172";
      runtime = "/run/pi-native-cutover-172";
      permit = "/run/pi-native-cutover-172-approved";
      tools = {
        converter = "${bridge.package}/bin/pi-bridge-migrate";
        bwrap = lib.getExe pkgs.bubblewrap;
        runuser = "${pkgs.util-linux}/bin/runuser";
        env = "${pkgs.coreutils}/bin/env";
        systemctl = "${pkgs.systemd}/bin/systemctl";
        syncthing = lib.getExe config.services.syncthing.package;
        git = lib.getExe pkgs.git;
      };
    }
  );
  program = pkgs.writeShellScriptBin "pi-native-cutover-172" ''
    set -euo pipefail
    if [[ "$#" != 1 ]]; then
      echo 'Usage: pi-native-cutover-172 run|permit-text|gate|gate-native' >&2
      exit 2
    fi
    exec ${pkgs.python3}/bin/python3 ${./cutover-172.py} "$1" ${settings}
  '';
  gate = "${program}/bin/pi-native-cutover-172 gate";
  # Unit conditions run before sandbox/StateDirectory setup. ExecCondition alone
  # would let a premature NAS start re-own original state before capture.
  activationCondition =
    if cfg.startAfterMigration then "/run/pi-native-cutover-172/ready.json" else "!/";
in
{
  options.services.piNativeCutover172 = {
    enable = lib.custom.mkBoolOpt false "Enable the temporary, explicitly approved native bridge cutover job";
    startAfterMigration = lib.custom.mkBoolOpt false "Separate activation approval: permit bridge/NAS assistant startup after verified migration. Never implies native Pi launch or queue replay.";
    holdSynchronization = lib.custom.mkBoolOpt true "Keep state-sync declaratively paused during maintenance. Release only under separately approved cross-host synchronization restoration.";
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion =
          builtins.elem host [
            "grill"
            "nas"
          ]
          && bridge.enable
          && bridge.hostId == host
          && bridge.user == user;
        message = "The #172 adapter is restricted to the configured grill/NAS native bridge owner.";
      }
      {
        assertion =
          config.services.syncthing.enable
          && builtins.hasAttr "state-sync" config.services.syncthing.settings.folders;
        message = "The #172 adapter requires the declared state-sync folder; it cannot infer cross-host replication closure.";
      }
    ];

    environment.systemPackages = [ program ];
    # Only this owner can read the root-owned frozen input. A shared primary
    # group (often `users`) would expose private histories to other accounts.
    users.groups.pi-native-cutover-172.members = [ user ];
    # Persistent masks contain no legacy runtime. Runtime stop still verifies
    # already-running loaded units; removal from Nix is not process exit proof.
    # Use NixOS's unit generator: /etc/systemd/user is already a generated
    # symlink, so nested environment.etc entries cannot be installed beneath it.
    systemd.user.units =
      userConsumers
      |> map (name: {
        inherit name;
        value.enable = false;
      })
      |> builtins.listToAttrs;

    services.syncthing.settings.folders."state-sync".paused = lib.mkIf cfg.holdSynchronization (
      lib.mkForce true
    );
    # Exclude only the retained Pi spool from cleanup during this temporary
    # adapter's lifetime. Existing in-progress cleanup is separately screened.
    systemd.tmpfiles.rules = lib.optional nas "x /var/lib/pi-chat-files - - - -";

    systemd.services = {
      pi-native-cutover-172 = {
        description = "One-time offline native Matrix bridge conversion (#172)";
        wantedBy = [ "multi-user.target" ];
        wants = [ "syncthing.service" ];
        after = [
          "local-fs.target"
          "syncthing.service"
          "syncthing-init.service"
        ]
        ++
          lib.optional (config.users.users.${user}.uid != null)
            "user@${toString config.users.users.${user}.uid}.service";
        unitConfig.RequiresMountsFor = map (root: root.original) roots;
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${program}/bin/pi-native-cutover-172 run";
          Restart = "no";
          TimeoutStartSec = 1800;
          UMask = "0077";
          StateDirectory = "pi-native-cutover-172";
          StateDirectoryMode = "0755";
          RuntimeDirectory = "pi-native-cutover-172";
          RuntimeDirectoryMode = "0755";
        };
      };
    }
    // lib.optionalAttrs nas {
      pi-chat-model = {
        unitConfig.ConditionPathExists = activationCondition;
        serviceConfig = {
          ExecCondition = [ gate ];
          TimeoutStartSec = 1500;
        };
      };
      pi-chat-transport = {
        unitConfig.ConditionPathExists = activationCondition;
        serviceConfig = {
          ExecCondition = [ gate ];
          TimeoutStartSec = 1500;
        };
      };
    };

    # A user unit cannot Requires= a system unit. The root-owned boot readiness
    # receipt crosses that seam; ExecCondition 1 skips rather than starts/replays.
    systemd.user.services.pi-matrix-bridge = {
      unitConfig.ConditionPathExists = activationCondition;
      serviceConfig = {
        ExecCondition = [ "${program}/bin/pi-native-cutover-172 gate-native" ];
        TimeoutStartSec = 1500;
      };
    };
    # No tmux/Pi PartOf, BindsTo, Requires, stop hooks or automatic replacement.
  };
}
