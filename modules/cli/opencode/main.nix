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
  sops.secrets.context7 = { };
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
        lite_google = {
          npm = "@ai-sdk/openai-compatible";
          name = "Google";
          options = {
            baseURL = "https://litellm.bepis.lol";
            apiKey = "{file:${config.sops.secrets.litellm_api.path}}";
          };
          models = {
            gemini-3-flash-preview = {
              name = "gemini-3-flash-preview";
            };
            gemini-3-pro-preview = {
              name = "gemini-3-pro-preview";
            };
          };
        };
        lite_anthropic = {
          npm = "@ai-sdk/openai-compatible";
          name = "Anthropic";
          options = {
            baseURL = "https://litellm.bepis.lol";
            apiKey = "{file:${config.sops.secrets.litellm_api.path}}";
          };
          models = {
            claude-opus-4-5 = {
              name = "claude-opus-4-5";
            };
            claude-sonnet-4-5 = {
              name = "claude-sonnet-4-5";
            };
            claude-haiku-4-5 = {
              name = "claude-haiku-4-5";
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
            "gpt-5.2" = {
              name = "gpt-5.2";
            };
            gpt-5-1-codex = {
              name = "gpt-5.1-codex-max";
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
        context7 = {
          enabled = true;
          type = "local";
          command = [
            "${pkgs.nodejs}/bin/npx"
            "-y"
            "@upstash/context7-mcp"
          ];
          environment = {
            CONTEXT7_API_KEY = "$(cat ${config.sops.secrets.context7.path})";
          };
        };
        nixos = {
          enabled = true;
          type = "local";
          command = [
            "nix"
            "run"
            "github:utensils/mcp-nixos"
            "--"
          ];
        };
      };
    };
  };
}
