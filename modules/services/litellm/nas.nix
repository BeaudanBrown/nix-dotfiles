{ config, ... }:
let
  litellmDomain = "litellm.bepis.lol";
  portKey = "litellm";
in
{
  custom.ports.requests = [ { key = portKey; } ];

  hostedServices = [
    {
      domain = litellmDomain;
      upstreamHost = config.services.litellm.host;
      upstreamPort = toString config.custom.ports.assigned.${portKey};
      tailnet = true;
    }
  ];

  services.litellm = {
    enable = true;
    port = config.custom.ports.assigned.${portKey};
    environmentFile = config.sops.secrets."litellm/env".path;
    settings = {
      litellm_settings = {
        drop_params = true;
      };
      model_list = [
        {
          model_name = "gpt-3.5-turbo";
          litellm_params = {
            model = "openai/gpt-3.5-turbo";
            api_key = "os.environ/OPENAI_API_KEY";
          };
        }
        {
          model_name = "o3";
          litellm_params = {
            model = "openai/o3";
            api_key = "os.environ/OPENAI_API_KEY";
          };
        }
        {
          model_name = "gpt-5-mini";
          litellm_params = {
            model = "openai/gpt-5";
            api_key = "os.environ/OPENAI_API_KEY";
          };
        }
        {
          model_name = "gpt-5";
          litellm_params = {
            model = "openai/gpt-5";
            api_key = "os.environ/OPENAI_API_KEY";
          };
        }
        {
          model_name = "claude-sonnet-4-5";
          litellm_params = {
            model = "anthropic/claude-sonnet-4-5";
            api_key = "os.environ/ANTHROPIC_API_KEY";
          };
        }
        {
          model_name = "claude-opus-4";
          litellm_params = {
            model = "anthropic/claude-opus-4-20250514";
            api_key = "os.environ/ANTHROPIC_API_KEY";
          };
        }
        {
          model_name = "claude-haiku-4-5";
          litellm_params = {
            model = "anthropic/claude-haiku-4-5";
            api_key = "os.environ/ANTHROPIC_API_KEY";
          };
        }
        {
          model_name = "gemini-2.5-flash";
          litellm_params = {
            model = "gemini/gemini-2.5-flash-preview-04-17";
            api_key = "os.environ/GOOGLE_API_KEY";
          };
        }
        {
          model_name = "gemini-2.5-pro";
          litellm_params = {
            model = "gemini/gemini-2.5-pro-preview-05-06";
            api_key = "os.environ/GOOGLE_API_KEY";
          };
        }
        {
          model_name = "gemini-3-pro-preview";
          litellm_params = {
            model = "gemini/gemini-3-pro-preview";
            api_key = "os.environ/GOOGLE_API_KEY";
          };
        }
      ];
    };
  };
  sops.secrets."litellm/env" = { };

  # Persist LiteLLM state in local Postgres via peer auth
  # users.users.litellm = {
  #   group = "litellm";
  #   isSystemUser = true;
  # };
  # users.groups.litellm = { };

  # systemd.services.litellm = {
  #   after = [ "postgresql.service" ];
  #   requires = [ "postgresql.service" ];
  #   serviceConfig = {
  #     DynamicUser = lib.mkForce false;
  #     User = "litellm";
  #     Group = "litellm";
  #   };
  # };

  # services.postgresql = {
  #   enable = true;
  #   ensureUsers = [
  #     {
  #       name = "litellm";
  #       ensureDBOwnership = true;
  #     }
  #   ];
  #   ensureDatabases = [ "litellm" ];
  # };
}
