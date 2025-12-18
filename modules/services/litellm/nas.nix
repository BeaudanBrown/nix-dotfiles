{
  config,
  lib,
  pkgs,
  ...
}:
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

  virtualisation.oci-containers.containers = {
    "litellm" =
      let
        litellm_config = {
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
              model_name = "gpt-5.2";
              litellm_params = {
                model = "openai/gpt-5";
                api_key = "os.environ/OPENAI_API_KEY";
              };
            }
            {
              model_name = "gpt-5.1-codex-max";
              litellm_params = {
                model = "openai/gpt-5";
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
              model_name = "claude-opus-4-5";
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
              model_name = "gemini-3-flash-preview";
              litellm_params = {
                model = "gemini/gemini-3-flash-preview";
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
        litellm_yaml = pkgs.writeText "config.yaml" (lib.generators.toYAML { } litellm_config);
      in
      {
        image = "docker.litellm.ai/berriai/litellm-database:main-stable";
        autoStart = true;
        ports = [
          "127.0.0.1:${toString config.custom.ports.assigned.${portKey}}:4000"
        ];
        environment = {
          DATABASE_URL = "postgresql://litellm@localhost/litellm?host=/var/run/postgresql&schema=litellm";
          STORE_MODEL_IN_DB = "True";
          HOST = "0.0.0.0";
          PORT = "4000";
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

  sops.secrets."litellm/env" = { };
  sops.secrets."litellm/db_env" = { };
}
