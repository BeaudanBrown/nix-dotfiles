# Evaluation only. Fetch only the two public/local locked inputs below, never
# the fleet flake or its private sopsSecrets input. No derivation is realized.
let
  lock = builtins.fromJSON (builtins.readFile ../flake.lock);
  nixpkgsNode = lock.nodes.${lock.nodes.${lock.root}.inputs.nixpkgs}.locked;
  nixpkgs = builtins.fetchTree nixpkgsNode;
  sandboxNode = lock.nodes.agent-sandbox.locked;
  sandbox = builtins.getFlake "git+${sandboxNode.url}?rev=${sandboxNode.rev}";
  lib = import (nixpkgs + "/lib");
  pkgs = import nixpkgs { system = "x86_64-linux"; };
  evaluate =
    extra:
    (import (nixpkgs + "/nixos/lib/eval-config.nix") {
      system = "x86_64-linux";
      specialArgs.inputs.agent-sandbox = sandbox;
      modules = [
        ../modules/services/agent-sandbox/trial.nix
        ({ ... }: {
          networking.hostName = "grill";
          system.stateVersion = "26.05";
          fileSystems."/" = {
            device = "/dev/synthetic";
            fsType = "ext4";
          };
          boot.loader.grub.devices = [ "nodev" ];
          users.users.beau = {
            uid = 1000;
            isNormalUser = true;
            extraGroups = [ "wheel" ];
          };
          security.sudo.execWheelOnly = true;
          nix.settings.trusted-users = [
            "root"
            "@wheel"
          ];
        })
        extra
      ];
    }).config;
  disabled = evaluate { };
  enabled = evaluate { local.agentSandboxTrial.enable = true; };
  unsafeSudo = evaluate {
    local.agentSandboxTrial.enable = true;
    security.sudo.execWheelOnly = lib.mkForce false;
  };
  wrongHost = evaluate {
    local.agentSandboxTrial.enable = true;
    networking.hostName = lib.mkForce "nas";
  };
  collision = evaluate {
    local.agentSandboxTrial.enable = true;
    users.users.other = {
      uid = 61950;
      isSystemUser = true;
      group = "nogroup";
    };
  };
  trusted = evaluate {
    local.agentSandboxTrial.enable = true;
    nix.settings.trusted-users = lib.mkForce [ "*" ];
  };
  unsafeSandbox = evaluate {
    local.agentSandboxTrial.enable = true;
    nix.settings.sandbox = lib.mkForce false;
  };
  fallback = evaluate {
    local.agentSandboxTrial.enable = true;
    nix.settings.sandbox-fallback = lib.mkForce true;
  };
  passes = c: lib.all (a: a.assertion) c.assertions;
  cfg = enabled.services.agent-sandbox;
  hostSource = builtins.readFile ../hosts/grill/default.nix;
in
assert lib.hasInfix "../../modules/services/agent-sandbox/trial.nix" hostSource;
assert !disabled.services.agent-sandbox.enable;
assert !(disabled.users.users ? agent-sandbox-trial);
assert !(disabled.systemd.services ? agent-sandbox);
assert !(disabled.environment.etc ? "agent-sandbox/installation.json");
assert passes enabled;
assert
  !passes unsafeSudo
  && !passes wrongHost
  && !passes collision
  && !passes trusted
  && !passes fallback
  && !passes unsafeSandbox;
assert enabled.security.sudo.execWheelOnly == disabled.security.sudo.execWheelOnly;
assert enabled.security.sudo.extraRules == disabled.security.sudo.extraRules;
assert enabled.nix.settings.trusted-users == disabled.nix.settings.trusted-users;
assert lib.elem "*" enabled.nix.settings.allowed-users;
assert enabled.nix.settings.sandbox && !enabled.nix.settings.sandbox-fallback;
assert cfg.user.uid == 61950 && cfg.user.gid == 61950 && cfg.operatorUid == 1000;
assert enabled.users.users.agent-sandbox-trial.extraGroups == [ ];
assert cfg.roots.trial.ceiling == "read-only" && cfg.roots.trial.defaultAccess == "read-only";
assert builtins.attrNames cfg.roots == [ "trial" ];
assert cfg.roots.trial.path == "/srv/agent-sandbox-trial";
assert
  cfg.roots.trial.exclusions == [
    {
      path = ".env";
      type = "file";
    }
  ];
assert cfg.seedProjects.trial-project.path == "/srv/agent-sandbox-trial/project";
assert cfg.aclProvisioning == "managed";
assert cfg.harnesses.trial-hello.credentials == { } && cfg.harnesses.trial-hello.state == { };
assert !cfg.harnesses.trial-hello.coordinator;
assert cfg.harnesses.trial-hello.executable == "${pkgs.hello}/bin/hello";
assert enabled.systemd.services.agent-sandbox.wantedBy == [ ];
assert sandbox.rev == sandboxNode.rev && sandbox.narHash == sandboxNode.narHash;
assert lib.hasInfix "git+${sandboxNode.url}?rev=${sandboxNode.rev}" (
  builtins.readFile ../flake.nix
);
{
  result = "passed";
  inherit (sandboxNode) rev;
  scope = "isolated consuming-module evaluation; no full-host build, activation or runtime proof";
}
