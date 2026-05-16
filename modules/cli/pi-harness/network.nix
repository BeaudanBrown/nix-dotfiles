{
  inputs,
  lib,
  pkgs,
  config,
  ...
}:
let
  piHarnessPackage = inputs.pi-harness.packages.${pkgs.system}.default;
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
              id = "sub-gpt-5.5";
              api = "openai-responses";
              reasoning = true;
              contextWindow = 272000;
              maxTokens = 16384;
            }
            {
              id = "sub-gpt-5.5-mini";
              api = "openai-responses";
              reasoning = true;
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
          ];
        };
      };
    }
  );
  piSettingsFile = pkgs.writeText "pi-settings.json" (
    builtins.toJSON {
      "$schema" =
        "https://raw.githubusercontent.com/badlogic/pi-mono/main/packages/coding-agent/src/core/settings-schema.json";
      defaultProvider = "litellm";
      defaultModel = "sub-gpt-5.5";
      defaultThinkingLevel = "medium";
      extensions = [
        "./extensions/web-search/index.ts"
        "./extensions/agentgraph/index.ts"
      ];
      skills = [ "./skills" ];
      prompts = [ "./prompts" ];
      themes = [ "./themes" ];
      enableSkillCommands = true;
      compaction = {
        enabled = true;
        reserveTokens = 16384;
        keepRecentTokens = 20000;
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
  };

  hm.primary.home.file = {
    ".pi/agent/settings.json".source = piSettingsFile;
    ".pi/agent/extensions".source = "${piHarnessPackage}/share/pi-harness/agent/extensions";
    ".pi/agent/skills".source = "${piHarnessPackage}/share/pi-harness/agent/skills";
    ".pi/agent/prompts".source = "${piHarnessPackage}/share/pi-harness/agent/prompts";
    ".pi/agent/themes".source = "${piHarnessPackage}/share/pi-harness/agent/themes";
  };
}
