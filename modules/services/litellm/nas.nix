{ config, lib, pkgs, ... }:
let
  stateDir = "/pool1/appdata/litellm";
in
{
  services.nginx = {
    virtualHosts = let
      base = locations: {
        inherit locations;

        forceSSL = true;
        enableACME = true;
      };
      proxy = port: base {
        "/".proxyPass = "http://127.0.0.1:" + toString(port) + "/";
      };
    in {
      "litellm.bepis.lol" = proxy 8223;
    };
  };

  systemd.tmpfiles.rules = [
    "d ${stateDir} 0755 litellm litellm - -"
  ];

  sops.secrets.litellm = {
    owner = "litellm";
    group = "litellm";
  };

  services.litellm = {
    enable = true;
    port = 8223;
    inherit stateDir;
    settings = {
      general_settings.master_key = "os.environ/LITELLM_MASTER_KEY";
      model_list = [
        {
          model_name = "gpt-3.5-turbo";
          litellm_params = {
            model = "openai/gpt-3.5-turbo";
            api_key = "os.environ/OPENAI_API_KEY";
          };
        }
      ];
    };
    # environment = {
    #   PRISMA_QUERY_ENGINE_BINARY = "${pkgs.prisma-engines}/bin/query-engine";
    # };
    environmentFile = config.sops.secrets.litellm.path;
  };

  users.users.litellm = {
    isSystemUser = true;
    home = stateDir;
    group = "litellm";
  };
  users.groups.litellm = { };

  systemd.services.litellm.serviceConfig = {
    DynamicUser = lib.mkForce false;
    WorkingDirectory = stateDir;
    User = "litellm";
    Group = "litellm";
  };

  # services.postgresql = {
  #   ensureDatabases = [ "litellm" ];
  #   identMap = ''
  #     superuser_map litellm litellm
  #     superuser_map root litellm
  #   '';
  # };
  # virtualisation.arion = {
  #   backend = "podman-socket";
  #   projects.litellm = {
  #     serviceName = "litellm";
  #     settings = {
  #       imports = [ ./litellm-compose.nix ];
  #     };
  #   };
  # };
}
