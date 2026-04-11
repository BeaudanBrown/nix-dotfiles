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

  environment.systemPackages = [
    inputs.pi-harness.packages.${pkgs.system}.default
  ];

  hm.primary.home.file.".pi/agent/models.json".source = piModelsFile;

  services.pi-harness = {
    enable = true;
    package = inputs.pi-harness.packages.${pkgs.system}.default;
  };
}
