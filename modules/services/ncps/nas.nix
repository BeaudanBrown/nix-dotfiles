{ config, lib, ... }:
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
      # Bind broadly on the host so k3s pods can reach the cache via a
      # cluster-local Service. Tailnet clients still use the existing nginx
      # proxy and cache.bepis.lol path.
      addr = "0.0.0.0:${toString config.custom.ports.assigned.${portKey}}";
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

  networking.firewall.interfaces.cni0.allowedTCPPorts = [ config.custom.ports.assigned.${portKey} ];

  sops.secrets."ncps" = {
    sopsFile = lib.custom.sopsFileForModule __curPos.file;
    mode = "0400";
    owner = "ncps";
    group = "ncps";
  };
}
