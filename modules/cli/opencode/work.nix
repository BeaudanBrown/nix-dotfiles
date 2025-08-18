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
            claude-sonnet-4 = {
              name = "sonnet-4";
            };
            gpt-5 = {
              name = "gpt-5";
            };
            gpt-5-mini = {
              name = "gpt-5-mini";
            };
          };
        };
      };
      mcp = {
        nixos = {
          type = "local";
          command = [
            "nix"
            "run"
            "github:utensils/mcp-nixos"
            "--"
          ];
          enabled = true;
        };
      };
    };
  };
}
