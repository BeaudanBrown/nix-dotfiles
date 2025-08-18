{ config, ... }:
{
  hostedServices = [
    {
      domain = "auth.bepis.lol";
      upstreamPort = "9000";
      webSockets = true;
    }
  ];
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
