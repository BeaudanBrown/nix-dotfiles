{ config, ... }:
{
  # TODO: I think nextcloud is doing it itself
  # hostedServices = [
  #   {
  #     domain = config.services.nextcloud.hostName;
  #     upstreamPort = toString config.services.nextcloud.port;
  #     webSockets = true;
  #   }
  # ];
  services.cloudflare-dyndns.domains = [
    config.services.nextcloud.hostName
  ];

  services.nextcloud = {
    enable = true;
    hostName = "cloud.bepis.lol";
    https = true;
    extraAppsEnable = true;
    extraApps = with config.services.nextcloud.package.packages.apps; {
      inherit richdocuments;
    };
    config = {
      dbtype = "sqlite";
      adminpassFile = config.sops.secrets.nextcloud_admin_pass.path;
    };
    configureRedis = true;
  };

  services.nginx.virtualHosts.${config.services.nextcloud.hostName} = {
    forceSSL = true;
    enableACME = true;
  };

  sops.secrets.nextcloud_admin_pass = {
    mode = "0600";
    owner = "nextcloud";
    group = "nextcloud";
  };
}
