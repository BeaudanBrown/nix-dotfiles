{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.local.agentSandboxTrial;
  sandbox = inputs.agent-sandbox;
  identity = 61950;
in
{
  imports = [ sandbox.nixosModules.default ];

  options.local.agentSandboxTrial.enable = lib.mkEnableOption "disposable Grill agent-sandbox trial (explicit provisioning required)";

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion =
          config.nix.settings.sandbox == true
          && config.nix.settings.sandbox-fallback == false
          && lib.any (
            name:
            builtins.elem name [
              "*"
              "agent-sandbox-trial"
              "@agent-sandbox-trial"
            ]
          ) config.nix.settings.allowed-users
          && lib.all (
            name:
            !(builtins.elem name [
              "*"
              "agent-sandbox-trial"
              "@agent-sandbox-trial"
            ])
          ) config.nix.settings.trusted-users;
        message = "Trial identity must be allowed but untrusted, with Nix sandboxing and no fallback; operator settings are not rewritten.";
      }
      {
        assertion = config.networking.hostName == "grill";
        message = "The disposable agent-sandbox trial is scoped to Grill.";
      }
      {
        assertion =
          lib.all (name: name == "agent-sandbox-trial" || config.users.users.${name}.uid != identity) (
            builtins.attrNames config.users.users
          )
          && lib.all (name: name == "agent-sandbox-trial" || config.users.groups.${name}.gid != identity) (
            builtins.attrNames config.users.groups
          );
        message = "Trial UID/GID 61950 must not alias another declared identity.";
      }
    ];
    services.agent-sandbox = {
      enable = true;
      package = sandbox.packages.${pkgs.stdenv.hostPlatform.system}.default;
      bubblewrapPackage = sandbox.packages.${pkgs.stdenv.hostPlatform.system}.bubblewrap;
      user = {
        name = "agent-sandbox-trial";
        uid = identity;
        gid = identity;
      };
      operatorUid = config.users.users.beau.uid;
      aclProvisioning = "managed";
      roots.trial = {
        path = "/srv/agent-sandbox-trial";
        defaultAccess = "read-only";
        ceiling = "read-only";
        exclusions = [
          {
            path = ".env";
            type = "file";
          }
        ];
      };
      seedProjects.trial-project = {
        root = "trial";
        path = "/srv/agent-sandbox-trial/project";
        access = "read-only";
      };
      # Existing immutable test executable, no Pi rollout, credentials or state.
      harnesses.trial-hello.executable = "${pkgs.hello}/bin/hello";
    };
    # Activation installs but does not start the service. Provision explicitly.
    systemd.services.agent-sandbox.wantedBy = lib.mkForce [ ];
  };
}
