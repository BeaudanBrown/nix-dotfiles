{
  config,
  inputs,
  pkgs,
  ...
}:
{
  sops.secrets.anthropic_api_key = {
    mode = "0600";
    path = "${config.hostSpec.home}/.config/anthropic.token";
    owner = config.hostSpec.username;
    inherit (config.users.users.${config.hostSpec.username}) group;
  };
  sops.secrets.openai_api_key = {
    mode = "0600";
    path = "${config.hostSpec.home}/.config/openai_api.token";
    owner = config.hostSpec.username;
    inherit (config.users.users.${config.hostSpec.username}) group;
  };
  hm.programs.opencode = {
    enable = true;
    package = inputs.nix-ai-tools.packages.${pkgs.system}.opencode;
    rules = ''
      You are a helpful AI assistant focused on development tasks.
      Always follow security best practices and coding conventions.
      When working with Nix configurations, maintain consistency with existing patterns.
    '';
    settings = {
      provider = {
        lite_anthropic = {
          npm = "@ai-sdk/openai-compatible";
          name = "Anthropic";
          options = {
            baseURL = "https://litellm.bepis.lol";
            apiKey = "{file:${config.sops.secrets.litellm_api.path}}";
          };
          models = {
            claude-sonnet-4 = {
              name = "claude-sonnet-4";
            };
          };
        };
        lite_openai = {
          npm = "@ai-sdk/openai";
          name = "OpenAI";
          options = {
            baseURL = "https://litellm.bepis.lol";
            apiKey = "{file:${config.sops.secrets.litellm_api.path}}";
          };
          models = {
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
        # TODO: Fix
        # context7 = {
        #   type = "remote";
        #   url = "https://mcp.context7.com/mcp";
        #   enabled = true;
        # };
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
