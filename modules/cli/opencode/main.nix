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
  sops.secrets.context7 = {
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
      agent = {
        general = {
          disable = true;
        };
        explore = {
          disable = true;
        };
        code-search = {
          mode = "subagent";
          description = "Specialized agent for searching the codebase and reading files. Use this for all retrieval tasks.";
          model = "lite_google/gemini-3-flash-preview";
          tools = {
            glob = true;
            grep = true;
            read = true;
            write = false;
            edit = false;
            bash = false;
          };
          prompt = ''
            You are a Code Search Specialist. Your ONLY goal is to retrieve information.
            - Use 'glob' to find file paths.
            - Use 'grep' to search content.
            - Use 'read' to inspect files.
            - Return concise summaries or direct code snippets.
            - NEVER attempt to modify code.
          '';
        };
        build = {
          mode = "primary";
          model = "lite_anthropic/claude-sonnet-4-5";
          tools = {
            write = true;
            edit = true;
            bash = true;
            code-search = true;
          };
          prompt = "You are the primary build agent. Delegate search tasks to @code-search to save context.";
        };
        plan = {
          mode = "primary";
          model = "lite_anthropic/claude-sonnet-4-5";
          tools = {
            write = false;
            edit = false;
            bash = false;
            code-search = true;
          };
          prompt = "You are a software architect. Create detailed plans. Delegate research to @code-search.";
        };
      };
      provider = {
        lite_google = {
          npm = "@ai-sdk/google";
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
            "gpt-5.1-codex-max" = {
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
        litellm = {
          enabled = true;
          type = "remote";
          url = "https://litellm.bepis.lol/mcp/";
          headers = {
            "x-litellm-api-key" = "Bearer {file:${config.sops.secrets.litellm_api.path}}";
          };
        };
        context7 = {
          enabled = true;
          type = "remote";
          url = "https://mcp.context7.com/mcp";
          headers = {
            CONTEXT7_API_KEY = "{file:${config.sops.secrets.context7.path}}";
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

        # nixos = {
        #   enabled = true;
        #   type = "local";
        #   command = [
        #     "${pkgs.uv}/bin/uvx"
        #     "mcp-nixos"
        #   ];
        # };
      };
    };
  };
}
