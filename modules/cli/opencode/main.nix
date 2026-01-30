{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
{
  sops.secrets.context7 = {
    sopsFile = lib.custom.sopsFileForModule __curPos.file;
    owner = config.hostSpec.username;
    inherit (config.users.users.${config.hostSpec.username}) group;
  };

  hm.primary.programs.opencode = {
    enable = true;
    package = inputs.nix-ai-tools.packages.${pkgs.system}.opencode;
    rules = ''
      You are a helpful AI assistant focused on development tasks.
      Always follow security best practices and coding conventions.
      When working with Nix configurations, maintain consistency with existing patterns.
    '';
    settings = {
      # Default model with high reasoning (kimi-k2.5 variants: toggle with Ctrl+T)
      model = "lite_moonshot/kimi-k2.5";
      # Small model for lightweight tasks (titles, summaries)
      small_model = "lite_openai/gpt-5-mini";
      agent = {
        general = {
          disable = true;
        };
        explore = {
          disable = true;
        };
        code-search = {
          mode = "subagent";
          description = "Read-only code retrieval specialist. Use ONLY for searching files, reading content, and gathering context. CANNOT edit, write, or modify files. Returns information for you to use.";
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
        github = {
          mode = "subagent";
          description = "Git specialist. Handles commits (short messages), diffs, and logs. Use ONLY when explicitly asked.";
          model = "lite_google/gemini-3-flash-preview";
          tools = {
            glob = false;
            grep = false;
            read = false;
            write = false;
            edit = false;
            bash = true;
          };
          prompt = ''
            You are a Git Operations Specialist.
            - Use 'bash' for git commands (commit, diff, log, status).
            - Commit messages MUST be concise (< 10 words).
            - Analyze diffs and repo state.
            - NEVER modify file contents directly.
          '';
        };
        build = {
          mode = "primary";
          model = "lite_moonshot/kimi-k2.5";
          tools = {
            write = true;
            edit = true;
            bash = true;
            code-search = true;
            github = true;
          };
          prompt = "You are the primary build agent. Delegate code search to @code-search, it cannot make changes. Delegate git tasks to @github ONLY when asked.";
        };
        plan = {
          mode = "primary";
          model = "lite_anthropic/claude-opus-4-5";
          tools = {
            write = false;
            edit = false;
            bash = false;
            code-search = true;
            github = true;
          };
          prompt = ''
            You are a software architect.
                        - Create plans, never attempt to change any files.
                        - Start each plan by first studying the existing code or specs, and then asking the user if you need clarification before you design a detailed plan.
                        - Delegate code search to @code-search, it cannot make changes.
                        - Use @github ONLY when asked and only for git information.'';
        };
      };
      provider = {
        lite_moonshot = {
          npm = "@ai-sdk/openai-compatible";
          name = "Moonshot";
          options = {
            baseURL = "https://litellm.bepis.lol";
            apiKey = "{file:${config.sops.secrets.litellm_api.path}}";
            includeUsage = true;
          };
          models = {
            "kimi-k2.5" = {
              name = "kimi-k2.5";
              reasoning = true;
              tool_call = true;
              interleaved = {
                field = "reasoning_content";
              };
              cost = {
                input = 0.60;
                output = 3.00;
              };
            };
          };
        };
        lite_google = {
          npm = "@ai-sdk/google";
          name = "Google";
          options = {
            baseURL = "https://litellm.bepis.lol";
            apiKey = "{file:${config.sops.secrets.litellm_api.path}}";
            includeUsage = true;
          };
          models = {
            gemini-3-flash-preview = {
              name = "gemini-3-flash-preview";
              cost = {
                input = 0.50;
                output = 3.00;
              };
            };
            gemini-3-pro-preview = {
              name = "gemini-3-pro-preview";
              reasoning = true;
              cost = {
                input = 2.00;
                output = 12.00;
              };
            };
          };
        };
        lite_anthropic = {
          npm = "@ai-sdk/openai-compatible";
          name = "Anthropic";
          options = {
            baseURL = "https://litellm.bepis.lol";
            apiKey = "{file:${config.sops.secrets.litellm_api.path}}";
            includeUsage = true;
          };
          models = {
            claude-opus-4-5 = {
              name = "claude-opus-4-5";
              reasoning = true;
              cost = {
                input = 5.00;
                output = 25.00;
              };
            };
            claude-sonnet-4-5 = {
              name = "claude-sonnet-4-5";
              reasoning = true;
              cost = {
                input = 3.00;
                output = 15.00;
              };
            };
            claude-haiku-4-5 = {
              name = "claude-haiku-4-5";
              cost = {
                input = 1.00;
                output = 5.00;
              };
            };
          };
        };
        lite_openai = {
          npm = "@ai-sdk/openai";
          name = "OpenAI";
          options = {
            baseURL = "https://litellm.bepis.lol";
            apiKey = "{file:${config.sops.secrets.litellm_api.path}}";
            includeUsage = true;
          };
          models = {
            "gpt-5.2" = {
              name = "gpt-5.2";
              reasoning = true;
              cost = {
                input = 1.75;
                output = 14.00;
              };
            };
            "gpt-5.2-codex" = {
              name = "gpt-5.2-codex";
              cost = {
                input = 1.75;
                output = 14.00;
              };
            };
            gpt-5-mini = {
              name = "gpt-5-mini";
              reasoning = true;
              cost = {
                input = 0.25;
                output = 2.00;
              };
            };
          };
        };
      };
      mcp = {
        github = {
          enabled = true;
          type = "local";
          command = [
            "${pkgs.bash}/bin/bash"
            "-c"
            "GITHUB_PERSONAL_ACCESS_TOKEN=$(${pkgs.gh}/bin/gh auth token) ${pkgs.github-mcp-server}/bin/github-mcp-server stdio"
          ];
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
      };
    };
  };
}
