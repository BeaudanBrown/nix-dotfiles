{
  config,
  lib,
  pkgs,
  ...
}:
let
  litellmDomain = "litellm.bepis.lol";
  portKey = "litellm";

  # Anthropic prompt caching: mark system prompt and conversation tail as
  # cache breakpoints.  Everything from the start of the prompt up to each
  # breakpoint becomes a cacheable prefix:
  #   • system  – AGENTS.md, persona, tool schemas — identical across turns
  #              AND across conversations in the same project (cross-convo
  #              cache hits at 0.1× base input cost).
  #   • last    – extends the cached prefix as the conversation grows so the
  #              full history is read from cache on every subsequent turn.
  # OpenAI/Google models cache automatically (no injection needed).
  anthropicCachePoints = [
    {
      location = "message";
      role = "system";
    }
    {
      location = "message";
      index = -1;
    }
  ];

  # ── Model catalog ──────────────────────────────────────────────────────
  # Single source of truth for every model routed through LiteLLM.
  # Other modules (openclaw, opencode, etc.) read the names from
  # config.custom.litellm.models instead of maintaining their own copy.
  modelList = [
    {
      model_name = "m3";
      litellm_params = {
        model = "openai/GLM-5-UD-Q8_K_XL-00001-of-00019.gguf";
        api_base = "http://m3.lan:8080/v1";
        api_key = "not-needed";
        cooldown_time = 0;
      };
    }
    {
      model_name = "glm-5";
      litellm_params = {
        api_base = "https://api.z.ai/api/coding/paas/v4";
        model = "zai/glm-5";
        api_key = "os.environ/ZAI_API_KEY";
      };
    }
    {
      model_name = "glm-4.7-flash";
      litellm_params = {
        api_base = "https://api.z.ai/api/coding/paas/v4";
        model = "zai/glm-4.7-flash";
        api_key = "os.environ/ZAI_API_KEY";
      };
    }
    {
      model_name = "gpt-5.2";
      litellm_params = {
        model = "openai/gpt-5.2";
        api_key = "os.environ/OPENAI_API_KEY";
        # OpenAI caches automatically — no injection points needed
      };
    }
    {
      model_name = "gpt-5.3-codex";
      litellm_params = {
        model = "openai/gpt-5.3-codex";
        api_key = "os.environ/OPENAI_API_KEY";
      };
    }
    {
      model_name = "gpt-5-mini";
      litellm_params = {
        model = "openai/gpt-5-mini";
        api_key = "os.environ/OPENAI_API_KEY";
      };
    }
    {
      model_name = "claude-haiku-4-5";
      litellm_params = {
        model = "anthropic/claude-haiku-4-5";
        api_key = "os.environ/ANTHROPIC_API_KEY";
        cache_control_injection_points = anthropicCachePoints;
      };
    }
    {
      model_name = "claude-sonnet-4-6";
      litellm_params = {
        model = "anthropic/claude-sonnet-4-6";
        api_key = "os.environ/ANTHROPIC_API_KEY";
        cache_control_injection_points = anthropicCachePoints;
      };
    }
    {
      model_name = "claude-opus-4-5";
      litellm_params = {
        model = "claude-opus-4-5";
        api_key = "os.environ/ANTHROPIC_API_KEY";
        cache_control_injection_points = anthropicCachePoints;
      };
    }
    {
      model_name = "claude-opus-4-6";
      litellm_params = {
        model = "claude-opus-4-6";
        api_key = "os.environ/ANTHROPIC_API_KEY";
        cache_control_injection_points = anthropicCachePoints;
      };
    }
    {
      model_name = "gemini-3-flash-preview";
      litellm_params = {
        model = "gemini/gemini-3-flash-preview";
        api_key = "os.environ/GOOGLE_API_KEY";
        # Gemini context caching uses a different API — injection points
        # are not the right mechanism here (requires explicit caching API calls)
      };
    }
    {
      model_name = "gemini-3.1-pro-preview";
      litellm_params = {
        model = "gemini/gemini-3.1-pro-preview";
        api_key = "os.environ/GOOGLE_API_KEY";
      };
    }
    {
      model_name = "gemini-2.5-flash-image";
      litellm_params = {
        model = "gemini/gemini-2.5-flash-image";
        api_key = "os.environ/GOOGLE_API_KEY";
      };
    }
    {
      model_name = "gemini-3-pro-image-preview";
      litellm_params = {
        model = "gemini/gemini-3-pro-image-preview";
        api_key = "os.environ/GOOGLE_API_KEY";
      };
    }
    {
      model_name = "kimi-k2.5";
      litellm_params = {
        model = "moonshot/kimi-k2.5";
        api_key = "os.environ/MOONSHOT_API_KEY";
        thinking = {
          type = "enabled";
          budget_tokens = 8192;
        };
      };
      model_info = {
        supports_reasoning = true;
      };
    }
    {
      model_name = "kimi-k2.5-no-think";
      litellm_params = {
        model = "moonshot/kimi-k2.5-no-think";
        api_key = "os.environ/MOONSHOT_API_KEY";
        thinking = {
          type = "disabled";
        };
      };
    }
  ];
in
{
  custom.ports.requests = [ { key = portKey; } ];

  # Expose model names to other modules (openclaw, opencode, etc.).
  custom.litellm.models = map (m: m.model_name) modelList;

  hostedServices = [
    {
      domain = litellmDomain;
      upstreamHost = "127.0.0.1";
      upstreamPort = toString config.custom.ports.assigned.${portKey};
      # Allow Joan to use
      tailnet = false;
    }
  ];

  virtualisation.oci-containers.containers = {
    "litellm" =
      let
        litellm_config = {
          general_settings = {
            # Keep models in the config file only — DB-seeding means new models
            # added to the Nix config are silently ignored after the first run.
            store_model_in_db = false;
            store_prompts_in_spend_logs = true;
            always_include_stream_usage = true;
          };
          litellm_settings = {
            modify_params = true;
            drop_params = true;
          };
          model_list = modelList;
        };
        litellm_yaml = pkgs.writeText "config.yaml" (lib.generators.toYAML { } litellm_config);
      in
      {
        image = "docker.litellm.ai/berriai/litellm-database:main-stable";
        pull = "always";
        autoStart = true;
        # Use host networking so the container shares the host's network stack,
        # giving it access to tailscale0 and tailnet DNS (needed to reach m3:8080).
        # With host networking, port mapping is not used — the container binds
        # directly to the host's PORT on all interfaces.
        extraOptions = [ "--network=host" ];
        environment = {
          DATABASE_URL = "postgresql://litellm@localhost/litellm?host=/var/run/postgresql&schema=litellm";
          # Align with general_settings.store_model_in_db = false above.
          STORE_MODEL_IN_DB = "False";
          HOST = "127.0.0.1";
          PORT = toString config.custom.ports.assigned.${portKey};
        };
        environmentFiles = [
          config.sops.secrets."litellm/env".path
        ];
        volumes = [
          "${litellm_yaml}:/app/config.yaml:ro"
          "/var/run/postgresql:/var/run/postgresql"
        ];
        cmd = [ "--config=/app/config.yaml" ];
      };
  };

  services.postgresql = {
    ensureUsers = [
      {
        name = "litellm";
        ensureDBOwnership = true;
      }
    ];
    ensureDatabases = [ "litellm" ];
    authentication = ''
      local all all trust
      host all all 127.0.0.1/32 trust
      host all all ::1/128 trust
    '';
  };

  sops.secrets."litellm/env" = {
    sopsFile = lib.custom.sopsFileForModule __curPos.file;
  };
  sops.secrets."litellm/db_env" = {
    sopsFile = lib.custom.sopsFileForModule __curPos.file;
  };
}
