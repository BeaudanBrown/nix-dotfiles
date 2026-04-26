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
            supportsReasoningEffort = false;
          };
          models = [
            {
              id = "sub-gpt-5.4";
              api = "openai-responses";
              reasoning = true;
            }
            {
              id = "sub-gpt-5.4-mini";
              api = "openai-responses";
              reasoning = true;
            }
            {
              id = "sub-gpt-5.4-pro";
              api = "openai-responses";
              reasoning = true;
            }
            {
              id = "sub-gpt-5.3-codex-spark";
              api = "openai-responses";
              reasoning = true;
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

  hm.primary.home.file.".pi/agent/models.json".source = piModelsFile;

  services.pi-harness = {
    enable = true;
    package = piHarnessPackage;
  };

  hm.primary.home.file = {
    ".pi/agent/settings.json".source = "${piHarnessPackage}/share/pi-harness/agent/settings.json";
    ".pi/agent/extensions".source = "${piHarnessPackage}/share/pi-harness/agent/extensions";
    ".pi/agent/skills".source = "${piHarnessPackage}/share/pi-harness/agent/skills";
    ".pi/agent/prompts".source = "${piHarnessPackage}/share/pi-harness/agent/prompts";
    ".pi/agent/themes".source = "${piHarnessPackage}/share/pi-harness/agent/themes";
  };
}
