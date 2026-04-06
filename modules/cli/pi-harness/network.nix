{
  inputs,
  lib,
  pkgs,
  config,
  ...
}:
let
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
              id = "gpt-5.2";
              reasoning = true;
            }
            {
              id = "gpt-5.3-codex";
              reasoning = true;
            }
            {
              id = "gpt-5-mini";
              reasoning = true;
            }
            {
              id = "claude-haiku-4-5";
              reasoning = true;
            }
            {
              id = "claude-sonnet-4-6";
              reasoning = true;
            }
            {
              id = "claude-opus-4-6";
              reasoning = true;
            }
            {
              id = "gemini-3-flash-preview";
              reasoning = true;
            }
            {
              id = "gemini-3.1-pro-preview";
              reasoning = true;
            }
            {
              id = "kimi-k2.5";
              reasoning = true;
            }
            {
              id = "m3";
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

  environment.systemPackages = [
    inputs.pi-harness.packages.${pkgs.system}.default
  ];

  hm.primary.home.file.".pi/agent/models.json".source = piModelsFile;

  services.pi-harness = {
    enable = true;
    package = inputs.pi-harness.packages.${pkgs.system}.default;
  };
}
