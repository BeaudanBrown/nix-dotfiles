{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.custom.localLlm;
  modelType = lib.types.submodule {
    options = {
      displayName = lib.mkOption {
        type = lib.types.str;
        description = "Human-readable model name shown by Pi.";
      };
      hfRepo = lib.mkOption {
        type = lib.types.str;
        description = "Hugging Face repository containing the GGUF.";
      };
      hfFile = lib.mkOption {
        type = lib.types.str;
        description = "GGUF filename within the Hugging Face repository.";
      };
      contextWindow = lib.mkOption {
        type = lib.types.ints.positive;
        description = "Context window advertised to Pi and configured in llama.cpp.";
      };
      maxTokens = lib.mkOption {
        type = lib.types.ints.positive;
        description = "Maximum output tokens advertised to Pi.";
      };
      reasoning = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether Pi should expose thinking controls for the model.";
      };
      input = lib.mkOption {
        type = lib.types.listOf (
          lib.types.enum [
            "text"
            "image"
          ]
        );
        default = [ "text" ];
        description = "Input modalities advertised to Pi.";
      };
      llamaSettings = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = { };
        description = "Additional llama.cpp router preset settings for this model.";
      };
    };
  };

  localLlm = pkgs.writeShellApplication {
    name = "local-llm";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.jq
      pkgs.openssh
    ];
    text = ''
      export LOCAL_LLM_API_KEY_FILE=${lib.escapeShellArg config.sops.secrets."pi/local_llm_api".path}
      export LOCAL_LLM_BASE_URL=${lib.escapeShellArg cfg.baseUrl}
      export LOCAL_LLM_DEFAULT_MODEL=${lib.escapeShellArg cfg.defaultModel}
      export LOCAL_LLM_HEALTH_URL=${lib.escapeShellArg cfg.healthUrl}
      export LOCAL_LLM_IS_SERVER=${
        lib.escapeShellArg (lib.boolToString (config.networking.hostName == cfg.serverHost))
      }
      export LOCAL_LLM_SERVER_HOST=${lib.escapeShellArg cfg.serverHost}
      exec ${pkgs.bash}/bin/bash ${./local-llm.sh} "$@"
    '';
  };
in
{
  options.custom.localLlm = {
    serverHost = lib.mkOption {
      type = lib.types.str;
      default = "grill";
      description = "Fleet hostname that serves local models.";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 18080;
      description = "Tailnet llama.cpp API port.";
    };
    idleSleepSeconds = lib.mkOption {
      type = lib.types.ints.positive;
      default = 900;
      description = "Seconds of inactivity before llama.cpp unloads model state.";
    };
    defaultModel = lib.mkOption {
      type = lib.types.str;
      default = "qwen3.8-27b";
      description = "Logical model ID used by the warm-up command.";
    };
    models = lib.mkOption {
      type = lib.types.attrsOf modelType;
      description = "Models served by the Grill llama.cpp router and exposed through Pi.";
      default = {
        "qwen3.8-27b" = {
          displayName = "Qwen3.8 27B on Grill";
          hfRepo = "unsloth/Qwen3.8-27B-GGUF";
          hfFile = "Qwen3.8-27B-IQ4_XS.gguf";
          contextWindow = 21504;
          maxTokens = 4096;
          reasoning = true;
          input = [ "text" ];
          llamaSettings = {
            cache-type-k = "q8_0";
            cache-type-v = "q8_0";
            flash-attn = "on";
            jinja = "on";
            n-gpu-layers = "all";
            parallel = 1;
            reasoning-format = "deepseek";
            reasoning-preserve = "on";
          };
        };
      };
    };
    baseUrl = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      description = "OpenAI-compatible Tailnet endpoint.";
    };
    healthUrl = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      description = "Tailnet llama.cpp health endpoint.";
    };
  };

  config = {
    assertions = [
      {
        assertion = lib.hasAttr cfg.defaultModel cfg.models;
        message = "custom.localLlm.defaultModel must name an entry in custom.localLlm.models";
      }
      {
        assertion = config.hostSpecs.${cfg.serverHost}.tailIP != "";
        message = "custom.localLlm.serverHost must have a Tailnet IP in hostSpecs";
      }
    ];

    custom.localLlm = {
      baseUrl = "http://${config.hostSpecs.${cfg.serverHost}.tailIP}:${toString cfg.port}/v1";
      healthUrl = "http://${config.hostSpecs.${cfg.serverHost}.tailIP}:${toString cfg.port}/health";
    };

    custom.ports.reserved = [ cfg.port ];

    sops.secrets."pi/local_llm_api" = {
      sopsFile = lib.custom.sopsFileForModule __curPos.file;
      owner = config.hostSpec.username;
      inherit (config.users.users.${config.hostSpec.username}) group;
      mode = "0400";
    };

    environment.systemPackages = [ localLlm ];
  };
}
