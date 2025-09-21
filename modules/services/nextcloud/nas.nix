{ config, ... }:
let
  domain = "cloud.bepis.lol";
in
{
  hostedServices = [
    {
      inherit domain;
      doNginx = false;
    }
  ];

  systemd.tmpfiles.rules = [
    "d /var/lib/nextcloud 0700 nextcloud nextcloud - -"
  ];

  services.nginx.virtualHosts.${config.services.nextcloud.hostName} = {
    forceSSL = true;
    useACMEHost = domain;
  };

  services.nextcloud = {
    enable = true;
    hostName = domain;
    https = true;
    extraAppsEnable = true;
    extraApps = with config.services.nextcloud.package.packages.apps; {
      inherit richdocuments;
    };
    database.createLocally = true;
    config = {
      dbtype = "pgsql";
      adminpassFile = config.sops.secrets."nextcloud/admin_pass".path;
    };
    configureRedis = true;
  };

  sops.secrets."nextcloud/admin_pass" = {
    mode = "0600";
    owner = "nextcloud";
    group = "nextcloud";
  };
}
