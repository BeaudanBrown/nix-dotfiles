{ config, ... }:
{
  hostedServices = [
    {
      domain = config.services.nextcloud.hostName;
      doNginx = false;
    }
  ];

  systemd.tmpfiles.rules = [
    "d /var/lib/nextcloud 0700 nextcloud nextcloud - -"
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

  sops.secrets.nextcloud_admin_pass = {
    mode = "0600";
    owner = "nextcloud";
    group = "nextcloud";
  };
}
