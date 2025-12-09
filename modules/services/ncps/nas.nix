{ config, ... }:
let
  domain = "cache.bepis.lol";
  portKey = "ncps";
in
{
  custom.ports.requests = [ { key = portKey; } ];

  hostedServices = [
    {
      inherit domain;
      upstreamPort = toString config.custom.ports.assigned.${portKey};
      tailnet = true;
      webSockets = false;
    }
  ];

  services.ncps = {
    enable = true;
    logLevel = "info";
    server = {
      addr = "127.0.0.1:${toString config.custom.ports.assigned.${portKey}}";
    };
    cache = {
      hostName = domain;
      databaseURL = "sqlite:///var/lib/ncps/db/ncps.db";
      maxSize = "500G";
      lru = {
        schedule = "0 2 * * *";
        scheduleTimeZone = "Australia/Melbourne";
      };
      secretKeyPath = config.sops.secrets."ncps".path;
      allowPutVerb = true;
      allowDeleteVerb = false;
    };

    upstream = {
      caches = [
        "https://cache.nixos.org"
      ];
      publicKeys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      ];
    };
  };

  sops.secrets."ncps" = {
    mode = "0400";
    owner = "ncps";
    group = "ncps";
  };
}
