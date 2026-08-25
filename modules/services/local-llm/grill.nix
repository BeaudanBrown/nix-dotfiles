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
  modelCacheDirectory = "/var/cache/llama-cpp/pinned-models";
  modelPath = model: "${modelCacheDirectory}/${model.sha256}-${model.hfFile}";
  modelSync = pkgs.writeShellApplication {
    name = "local-llm-model-sync";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
    ];
    text = ''
      install -d -m 0750 ${lib.escapeShellArg modelCacheDirectory}
      ${
        cfg.models
        |> lib.mapAttrsToList (
          _modelId: model:
          let
            target = modelPath model;
            url = "https://huggingface.co/${model.hfRepo}/resolve/${model.hfRevision}/${model.hfFile}";
          in
          ''
            target=${lib.escapeShellArg target}
            partial="$target.part"
            if [ -f "$target" ] && printf '%s  %s\n' ${lib.escapeShellArg model.sha256} "$target" | sha256sum --check --status; then
              printf 'Pinned local model is already verified: %s\n' "$target"
            else
              rm -f "$target"
              curl \
                --continue-at - \
                --fail \
                --location \
                --output "$partial" \
                --retry 3 \
                --retry-all-errors \
                ${lib.escapeShellArg url}
              if ! printf '%s  %s\n' ${lib.escapeShellArg model.sha256} "$partial" | sha256sum --check --status; then
                rm -f "$partial"
                echo "Pinned local model failed SHA-256 verification" >&2
                exit 1
              fi
              chmod 0440 "$partial"
              mv -f "$partial" "$target"
              printf 'Pinned local model verified: %s\n' "$target"
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

  # Provision the router without loading it at boot. Once manually started,
  # llama.cpp unloads idle model state while leaving the lightweight router up.
  systemd.services.llama-cpp = {
    wantedBy = lib.mkForce [ ];
    preStart = ''
      ${lib.getExe modelSync}
    '';
    after = [ "tailscaled.service" ];
    wants = [ "tailscaled.service" ];
    serviceConfig = {
      LoadCredential = [
        "local-llm-api-key:${config.sops.secrets."pi/local_llm_api".path}"
      ];
      RestartSec = lib.mkForce "5s";
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
          ];
    }
  ];
}
