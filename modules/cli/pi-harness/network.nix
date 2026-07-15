{
  inputs,
  lib,
  pkgs,
  config,
  options,
  ...
}:
let
  piHarnessPackage = inputs.pi-harness.packages.${pkgs.stdenv.hostPlatform.system}.default;
  piModelsFile = pkgs.writeText "pi-models.json" (
    builtins.toJSON {
      providers = {
        litellm = {
          baseUrl = "https://litellm.bepis.lol/v1";
          api = "openai-completions";
          apiKey = "!cat ${config.sops.secrets."pi/litellm_api".path}";
          compat = {
            supportsDeveloperRole = false;
            supportsReasoningEffort = true;
            reasoningEffortMap = {
              minimal = "low";
              low = "low";
              medium = "medium";
              high = "high";
              xhigh = "xhigh";
            };
          };
          models = [
            {
              id = "gpt-5.5";
              api = "openai-responses";
              reasoning = true;
              input = [
                "text"
                "image"
              ];
              contextWindow = 272000;
              maxTokens = 16384;
            }
            {
              id = "claude-opus-4-8";
              api = "openai-responses";
              reasoning = true;
              input = [
                "text"
                "image"
              ];
              contextWindow = 272000;
              maxTokens = 16384;
            }
            {
              id = "sub-gpt-5.5";
              api = "openai-responses";
              reasoning = true;
              input = [
                "text"
                "image"
              ];
              contextWindow = 272000;
              maxTokens = 16384;
            }
            {
              id = "sub-gpt-5.5-mini";
              api = "openai-responses";
              reasoning = true;
              input = [
                "text"
                "image"
              ];
              contextWindow = 272000;
              maxTokens = 16384;
            }
            {
              id = "sub-gpt-5.3-codex-spark";
              api = "openai-responses";
              reasoning = true;
              contextWindow = 128000;
              maxTokens = 16384;
            }
            {
              id = "kimi-k2.7-code";
              api = "openai-completions";
              reasoning = true;
              input = [
                "text"
                "image"
              ];
              contextWindow = 262144;
              maxTokens = 16384;
              cost = {
                input = 0.95;
                output = 4.00;
                cacheRead = 0.19;
                cacheWrite = 0.95;
              };
              thinkingLevelMap = {
                off = null;
              };
            }
          ];
        };
      };
    }
  );
in
{
  sops.secrets."pi/litellm_api" = {
    sopsFile = lib.custom.sopsFileForModule __curPos.file;
    owner = config.hostSpec.username;
    inherit (config.users.users.${config.hostSpec.username}) group;
    mode = "0400";
  };

  sops.secrets."agentgraph/env" = {
    sopsFile = lib.custom.sopsFileForModule __curPos.file;
    owner = config.hostSpec.username;
    inherit (config.users.users.${config.hostSpec.username}) group;
    mode = "0400";
  };

  hm.primary.home.file.".pi/agent/models.json".source = piModelsFile;
  hm.primary.home.sessionVariables = {
    PI_WEB_SEARCH_BASE_URL = "https://litellm.bepis.lol/openai_passthrough/v1";
    PI_WEB_SEARCH_MODEL = "gpt-5-mini";
    PI_WEB_SEARCH_API_KEY_COMMAND = "cat ${config.sops.secrets."pi/litellm_api".path}";
  };

  services.pi-harness = {
    enable = true;
    package = piHarnessPackage;
    agentgraph.environmentFile = config.sops.secrets."agentgraph/env".path;
  }
  // lib.optionalAttrs (lib.hasAttrByPath [ "services" "pi-harness" "lsp" "enable" ] options) {
    lsp.enable = true;
  }
  // lib.optionalAttrs (lib.hasAttrByPath [ "services" "pi-harness" "diagrams" "enable" ] options) {
    diagrams.enable = true;
  };
}
