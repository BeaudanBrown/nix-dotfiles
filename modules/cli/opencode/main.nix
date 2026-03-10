{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  # All model names available through the LiteLLM proxy (single source of truth).
  litellmModelNames = config.custom.litellm.models;

  # Model names referenced by opencode provider configs below.  Kept in
  # sync manually but validated by the assertion — if you add a model to
  # a provider block, add its litellm name here too.
  opencodeModelNames = [
    "kimi-k2.5"
    "gemini-3-flash-preview"
    "gemini-3.1-pro-preview"
    "claude-opus-4-5"
    "claude-opus-4-6"
    "claude-sonnet-4-6"
    "claude-haiku-4-5"
    "m3"
    "gpt-5.2"
    "gpt-5.3-codex"
    "gpt-5-mini"
  ];
in
{
  # Catch model drift: every model referenced in opencode providers must
  # exist in the litellm catalog.  Evaluates at build time so mismatches
  # are caught before deploy, not at runtime.
  assertions = lib.optionals (litellmModelNames != [ ]) (
    map (name: {
      assertion = builtins.elem name litellmModelNames;
      message = "opencode provider references model '${name}' which is not in custom.litellm.models";
    }) opencodeModelNames
  );

  sops.secrets.context7 = {
    sopsFile = lib.custom.sopsFileForModule __curPos.file;
    owner = config.hostSpec.username;
    inherit (config.users.users.${config.hostSpec.username}) group;
  };

  environment.systemPackages = [
    inputs.nix-ai-tools.packages.${pkgs.system}.amp
    inputs.nix-ai-tools.packages.${pkgs.system}.gemini-cli
    inputs.nix-ai-tools.packages.${pkgs.system}.codex
    inputs.nix-ai-tools.packages.${pkgs.system}.pi
  ];

  hm.primary.programs.opencode = {
    enable = true;
    package = inputs.nix-ai-tools.packages.${pkgs.system}.opencode;
    rules = ''
      You are a helpful AI assistant focused on development tasks.
      Always follow security best practices and coding conventions.
      When working with Nix configurations, maintain consistency with existing patterns.
    '';
    settings = {
      model = "lite_moonshot/kimi-k2.5";
      small_model = "lite_openai/gpt-5-mini";

      # Disable ALL MCP tools globally - agents must explicitly enable what they need
      tools = {
        "local-rag_*" = false;
        "github_*" = false;
        "context7_*" = false;
        "nixos_*" = false;
        "rag_*" = false;
      };

      agent = {
        # Disable default agents
        general = {
          disable = true;
        };
        explore = {
          disable = true;
        };

        # Minimal agent for non-interactive/scripting use - no MCPs
        minimal = {
          mode = "primary";
          description = "Minimal agent for scripting with no external MCPs to avoid context pollution";
          model = "lite_openai/gpt-5-mini";
          tools = {
            # Core file operations only
            write = true;
            edit = true;
            read = true;
            glob = true;
            grep = true;
            bash = true;
            # Just context7 enabled
            "context7_*" = false;
          };
          prompt = "You are a minimal agent for non-interactive tasks. Work with local files only. Do not use external MCP servers.";
        };

        code-search = {
          mode = "subagent";
          description = "Read-only code retrieval specialist. Use ONLY for searching files, reading content, and gathering context. CANNOT edit, write, or modify files. Returns information for you to use.";
          model = "lite_google/gemini-3-flash-preview";
          tools = {
            # Core tools only - no MCPs needed for code search
            glob = true;
            grep = true;
            read = true;
            write = false;
            edit = false;
            bash = false;
            "context7_*" = true;
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
            # Enable GitHub MCP for this agent
            "github_*" = true;
            bash = true;
          };
          prompt = ''
            You are a Git Operations Specialist.
            - Use 'bash' for git commands (commit, diff, log, status).
            - Use GitHub MCP tools for GitHub operations.
            - Commit messages MUST be concise (< 10 words).
            - Analyze diffs and repo state.
            - NEVER modify file contents directly.
          '';
        };

        build-tests = {
          mode = "subagent";
          description = "Build/test runner. Executes nix build/check/test commands and summarizes results with relevant error snippets.";
          model = "lite_openai/gpt-5-mini";
          tools = {
            bash = true;
          };
          prompt = ''
            You are a build/test runner.
            - Use 'bash' to run build/test commands (e.g., nix build, nix flake check).
            - Summarize success or failure succinctly.
            - On failure, include only the minimal relevant error snippets and the failing step.
            - Keep output brief to preserve the primary agent's context window.
            - NEVER modify files or suggest edits.
          '';
        };

        build = {
          mode = "primary";
          model = "lite_moonshot/kimi-k2.5";
          tools = {
            write = true;
            edit = true;
            bash = true;
            code-search = true; # Delegation to subagent
            github = true; # Delegation to subagent
            # Enable specific MCPs for the build agent
            "nixos_*" = true; # For Nix operations
            "context7_*" = true;
            "github_*" = true;
          };
          prompt = "You are the primary build agent. Delegate code search to @code-search, it cannot make changes. Delegate build/test commands to @build-tests to keep context clear. Delegate git tasks to @github ONLY when asked.";
        };

        plan = {
          mode = "primary";
          model = "lite_anthropic/claude-opus-4-6";
          tools = {
            write = false;
            edit = false;
            bash = false;
            code-search = true;
            github = true;
            # Enable research MCPs for planning
            "context7_*" = true; # For library documentation
            "rag_*" = true; # For general knowledge
          };
          prompt = ''
            You are a software architect.
            - Create plans, never attempt to change any files.
            - Start each plan by first studying the existing code or specs, and then asking the user if you need clarification before you design a detailed plan.
            - Delegate code search to @code-search, it cannot make changes.
            - Use @github ONLY when asked and only for git information.
          '';
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
        lite_zai = {
          npm = "@ai-sdk/openai-compatible";
          name = "lite_zai";
          options = {
            baseURL = "https://litellm.bepis.lol";
            apiKey = "{file:${config.sops.secrets.litellm_api.path}}";
          };
          models = {
            glm-5 = {
              name = "glm-5";
            };
            "glm-4.7-flash" = {
              name = "glm-4.7-flash";
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
            "gemini-3.1-pro-preview" = {
              name = "gemini-3.1-pro-preview";
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
                cache_read = 0.50;
                cache_write = 6.25;
              };
            };
            claude-opus-4-6 = {
              name = "claude-opus-4-6";
              reasoning = true;
              cost = {
                input = 5.00;
                output = 25.00;
                cache_read = 0.50;
                cache_write = 6.25;
              };
            };
            claude-sonnet-4-6 = {
              name = "claude-sonnet-4-6";
              reasoning = true;
              cost = {
                input = 3.00;
                output = 15.00;
                cache_read = 0.30;
                cache_write = 3.75;
              };
            };
            claude-haiku-4-5 = {
              name = "claude-haiku-4-5";
              cost = {
                input = 1.00;
                output = 5.00;
                cache_read = 0.10;
                cache_write = 1.25;
              };
            };
          };
        };
        m3 = {
          npm = "@ai-sdk/openai-compatible";
          name = "M3";
          options = {
            baseURL = "https://litellm.bepis.lol";
            apiKey = "{file:${config.sops.secrets.litellm_api.path}}";
          };
          models = {
            "m3" = {
              name = "m3";
              reasoning = true;
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
                cache_read = 0.4375; # 50% of input (automatic, no write surcharge)
                cache_write = 1.75;
              };
            };
            "gpt-5.3-codex" = {
              name = "gpt-5.3-codex";
              cost = {
                input = 1.75;
                output = 14.00;
                cache_read = 0.4375;
                cache_write = 1.75;
              };
            };
            gpt-5-mini = {
              name = "gpt-5-mini";
              reasoning = true;
              cost = {
                input = 0.25;
                output = 2.00;
                cache_read = 0.0625;
                cache_write = 0.25;
              };
            };
          };
        };
      };
      mcp = {
        "local-rag" = {
          enabled = true;
          type = "local";
          timeout = 1200000;
          command = [
            "${pkgs.bash}/bin/bash"
            "-c"
            "PATH=${pkgs.nodejs}/bin:$PATH npx -y mcp-local-rag"
          ];
          environment = {
            BASE_DIR = config.hostSpec.home;
          };
        };

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

        rag = {
          enabled = true;
          type = "remote";
          url = "https://rag-mcp.bepis.lol/sse";
        };
      };
    };
  };
}
