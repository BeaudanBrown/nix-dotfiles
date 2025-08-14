{ config, ... }:
{
  services.nginx.virtualHosts."auth.bepis.lol" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      # This port is currently hard coded in the module
      proxyPass = "http://127.0.0.1:9000";
      proxyWebsockets = true;
    };
  };
  services.authentik = {
    enable = true;
    environmentFile = config.sops.secrets.authentik_env.path;
    settings = {
      disable_startup_analytics = true;
      avatars = "attributes.avatar,gravatar,initials";
    };
  };
  sops.secrets.authentik_env = { };
}
