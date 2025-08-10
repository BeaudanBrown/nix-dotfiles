{ config, ... }:
{
  services.nginx.virtualHosts."litellm.bepis.lol" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString config.services.litellm.port}";
    };
  };
  services.litellm = {
    enable = true;
    environmentFile = config.sops.secrets.litellm.path;
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
          model_name = "claude-sonnet-4";
          litellm_params = {
            model = "anthropic/claude-sonnet-4-20250514";
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
          model_name = "claude-3-5-haiku";
          litellm_params = {
            model = "anthropic/claude-3-5-haiku-20241022";
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
      ];
    };
  };
  sops.secrets.litellm = { };

  # TODO: Link this up with postgres
  # users.users.litellm = {
  #   group = "litellm";
  #   isSystemUser = true;
  # };
  # users.groups.litellm = { };

  # systemd.services.litellm.serviceConfig = {
  #   DynamicUser = lib.mkForce false;
  #   User = "litellm";
  #   Group = "litellm";
  # };

  # services.postgresql = {
  #   ensureUsers = [
  #     {
  #       name = "litellm";
  #       ensureDBOwnership = true;
  #     }
  #   ];
  #   ensureDatabases = [ "litellm" ];
  # };
}
