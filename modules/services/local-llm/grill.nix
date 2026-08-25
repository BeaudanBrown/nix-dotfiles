{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.custom.localLlm;
  system = pkgs.stdenv.hostPlatform.system;
  llamaPackage = inputs.llama-cpp.packages.${system}.rocm.override {
    rocmGpuTargets = "gfx1030";
    useWebUi = false;
  };
  modelOwner = "local-llm-model";
  modelGroup = "local-llm-model";
  modelCacheDirectory = "/var/lib/local-llm-models";
  legacyModelCacheDirectory = "/var/cache/llama-cpp/pinned-models";
  modelPath = model: "${modelCacheDirectory}/${model.sha256}-${model.hfFile}";
  modelManager = pkgs.writeShellApplication {
    name = "local-llm-model-manager";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
    ];
    text = lib.concatMapStringsSep "\n" (model: ''
      (
        export LOCAL_LLM_MODEL_DIRECTORY=${lib.escapeShellArg modelCacheDirectory}
        export LOCAL_LLM_MODEL_REPOSITORY=${lib.escapeShellArg model.hfRepo}
        export LOCAL_LLM_MODEL_REVISION=${lib.escapeShellArg model.hfRevision}
        export LOCAL_LLM_MODEL_FILENAME=${lib.escapeShellArg model.hfFile}
        export LOCAL_LLM_MODEL_SHA256=${lib.escapeShellArg model.sha256}
        export LOCAL_LLM_MODEL_SIZE=${toString model.size}
        export LOCAL_LLM_MODEL_URL=${lib.escapeShellArg "https://huggingface.co/${model.hfRepo}/resolve/${model.hfRevision}/${model.hfFile}"}
        export LOCAL_LLM_MODEL_OWNER=${lib.escapeShellArg modelOwner}
        export LOCAL_LLM_MODEL_GROUP=${lib.escapeShellArg modelGroup}
        ${pkgs.bash}/bin/bash ${./model-manager.sh} "$1"
      )
    '') (lib.attrValues cfg.models);
  };
  modelMigration = pkgs.writeShellApplication {
    name = "local-llm-model-migrate";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      install -d -o ${modelOwner} -g ${modelGroup} -m 0750 ${lib.escapeShellArg modelCacheDirectory}
      ${
        cfg.models
        |> lib.mapAttrsToList (
          _modelId: model:
          let
            legacy = "${legacyModelCacheDirectory}/${model.sha256}-${model.hfFile}";
            target = modelPath model;
          in
          ''
            if [ -f ${lib.escapeShellArg legacy} ] && [ ! -e ${lib.escapeShellArg target} ]; then
              mv ${lib.escapeShellArg legacy} ${lib.escapeShellArg target}
              chown ${modelOwner}:${modelGroup} ${lib.escapeShellArg target}
              chmod 0440 ${lib.escapeShellArg target}
              echo "Migrated existing pinned model without re-downloading it"
            fi
          ''
        )
        |> lib.concatStringsSep "\n"
      }
    '';
  };
  modelsPreset = lib.mapAttrs (
    modelId: model:
    model.llamaSettings
    // {
      alias = modelId;
      ctx-size = model.contextWindow;
      model = modelPath model;
    }
  ) cfg.models;
  systemctl = "/run/current-system/sw/bin/systemctl";
in
{
  services.llama-cpp = {
    enable = true;
    package = llamaPackage;
    host = config.hostSpecs.${cfg.serverHost}.tailIP;
    port = cfg.port;
    inherit modelsPreset;
    extraFlags = [
      "--api-key-file"
      "/run/credentials/llama-cpp.service/local-llm-api-key"
      "--models-max"
      "1"
      "--no-ui"
      "--sleep-idle-seconds"
      (toString cfg.idleSleepSeconds)
    ];
  };

  users.groups.${modelGroup} = { };
  users.users.${modelOwner} = {
    isSystemUser = true;
    group = modelGroup;
  };

  systemd.services.local-llm-model-migrate = {
    description = "Adopt the previously verified local model cache";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe modelMigration;
      RemainAfterExit = true;
    };
  };

  systemd.services.local-llm-model-prepare = {
    description = "Prepare pinned local models";
    requires = [ "local-llm-model-migrate.service" ];
    wants = [ "network-online.target" ];
    after = [
      "local-llm-model-migrate.service"
      "network-online.target"
    ];
    script = ''
      ${lib.getExe modelManager} prepare
    '';
    serviceConfig = {
      Type = "oneshot";
      User = modelOwner;
      Group = modelGroup;
      StateDirectory = "local-llm-models";
      StateDirectoryMode = "0750";
      TimeoutStartSec = toString cfg.startupTimeoutSeconds;
    };
  };

  systemd.services.local-llm-model-verify = {
    description = "Fully verify pinned local models";
    requires = [ "local-llm-model-migrate.service" ];
    after = [ "local-llm-model-migrate.service" ];
    script = ''
      ${lib.getExe modelManager} verify
    '';
    serviceConfig = {
      Type = "oneshot";
      User = modelOwner;
      Group = modelGroup;
      StateDirectory = "local-llm-models";
      StateDirectoryMode = "0750";
      TimeoutStartSec = toString cfg.startupTimeoutSeconds;
    };
  };

  # Provision the router without loading it at boot. Once manually started,
  # llama.cpp unloads idle model state while leaving the lightweight router up.
  systemd.services.llama-cpp = {
    wantedBy = lib.mkForce [ ];
    requires = [ "local-llm-model-prepare.service" ];
    after = [
      "local-llm-model-prepare.service"
      "tailscaled.service"
    ];
    wants = [ "tailscaled.service" ];
    serviceConfig = {
      LoadCredential = [
        "local-llm-api-key:${config.sops.secrets."pi/local_llm_api".path}"
      ];
      RestartSec = lib.mkForce "5s";
      SupplementaryGroups = [ modelGroup ];
      TimeoutStartSec = toString cfg.startupTimeoutSeconds;
    };
  };

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ cfg.port ];

  # Permit the fleet lifecycle helper to control only this service over SSH.
  security.sudo.extraRules = [
    {
      users = [ config.hostSpec.username ];
      commands =
        map
          (action: {
            command = "${systemctl} ${action} llama-cpp.service";
            options = [ "NOPASSWD" ];
          })
          [
            "restart"
            "start"
            "stop"
          ]
        ++ [
          {
            command = "${systemctl} start local-llm-model-verify.service";
            options = [ "NOPASSWD" ];
          }
        ];
    }
  ];
}
