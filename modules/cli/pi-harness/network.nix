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
  localLlm = config.custom.localLlm;
  localLlmModels =
    localLlm.models
    |> lib.mapAttrsToList (
      modelId: model:
      {
        id = modelId;
        name = model.displayName;
        inherit (model)
          contextWindow
          input
          maxTokens
          reasoning
          ;
        cost = {
          input = 0;
          output = 0;
          cacheRead = 0;
          cacheWrite = 0;
        };
      }
      // lib.optionalAttrs model.reasoning {
        thinkingLevelMap = {
          minimal = "low";
          low = "low";
          medium = "medium";
          high = "xhigh";
          xhigh = "xhigh";
          max = "xhigh";
        };
      }
    );
  localLlmProvider = {
    baseUrl = localLlm.baseUrl;
    api = "openai-completions";
    apiKey = "!cat ${config.sops.secrets."pi/local_llm_api".path}";
    compat = {
      supportsDeveloperRole = false;
      supportsReasoningEffort = false;
      supportsStrictMode = false;
      maxTokensField = "max_tokens";
      thinkingFormat = "chat-template";
      chatTemplateKwargs = {
        enable_thinking = {
          "$var" = "thinking.enabled";
        };
        reasoning_effort = {
          "$var" = "thinking.effort";
          omitWhenOff = true;
        };
        preserve_thinking = true;
      };
    };
    models = localLlmModels;
  };
  litellmProvider = {
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
    ];
  };
  piModelsFile = pkgs.writeText "pi-models.json" (
    builtins.toJSON {
      providers = {
        local-llm = localLlmProvider;
        litellm = litellmProvider;
      };
    }
  );
  piLocalModelsFile = pkgs.writeText "pi-local-models.json" (
    builtins.toJSON {
      providers.local-llm = localLlmProvider;
    }
  );
  piLocalSettingsFile = pkgs.writeText "pi-local-settings.json" (
    builtins.toJSON {
      lastChangelogVersion = piHarnessPackage.pi.version;
      defaultProvider = "local-llm";
      defaultModel = localLlm.defaultModel;
      defaultThinkingLevel = "low";
      hideThinkingBlock = false;
      compaction = {
        enabled = true;
        reserveTokens = 4096;
        keepRecentTokens = 6000;
      };
      branchSummary.reserveTokens = 4096;
    }
  );
  piLocalAgentDir = "${config.hostSpec.home}/.pi/local-agent";
  piLocal = pkgs.writeShellApplication {
    name = "pi-local";
    text = ''
      export PI_CODING_AGENT_DIR=${lib.escapeShellArg piLocalAgentDir}
      export PI_CODING_AGENT_SESSION_DIR=${lib.escapeShellArg "${config.hostSpec.home}/.pi/agent/sessions"}
      exec ${piHarnessPackage}/bin/pi-r-local \
        --model ${lib.escapeShellArg "local-llm/${localLlm.defaultModel}"} \
        --thinking low \
        --system-prompt ${lib.escapeShellArg "You are a concise coding assistant. Inspect files before editing, make minimal correct changes, use the available tools when needed, and report results briefly."} \
        "$@"
    '';
  };
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

  hm.primary.home.file = {
    ".pi/agent/models.json".source = piModelsFile;
    ".pi/local-agent/models.json".source = piLocalModelsFile;
    ".pi/local-agent/settings.json".source = piLocalSettingsFile;
  };

  environment.systemPackages = [ piLocal ];

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
  }
  // lib.optionalAttrs (lib.hasAttrByPath [ "services" "pi-harness" "playwright" "enable" ] options) {
    playwright.enable = true;
  };
}
