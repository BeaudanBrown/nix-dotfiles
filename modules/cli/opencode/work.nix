{ config, ... }:
{
  sops.secrets.anthropic_api_key = {
    mode = "0600";
    path = "${config.hostSpec.home}/.config/anthropic.token";
    owner = config.hostSpec.username;
    inherit (config.users.users.${config.hostSpec.username}) group;
  };
  hm.programs.opencode = {
    enable = true;
    rules = ''
      You are a helpful AI assistant focused on development tasks.
      Always follow security best practices and coding conventions.
      When working with Nix configurations, maintain consistency with existing patterns.
    '';
    settings = {
      provider = {
        anthropic = {
          options = {
            apiKey = "{file:${config.sops.secrets.anthropic_api_key.path}}";
          };
          models = { };
        };
        litellm = {
          npm = "@ai-sdk/openai-compatible";
          name = "LiteLLM";
          options = {
            baseURL = "https://litellm.bepis.lol";
            apiKey = "{file:${config.sops.secrets.litellm_api.path}}";
          };
          models = {
            sonnet = {
              name = "claude-sonnet-4";
            };
          };
        };
      };
    };
  };
}
