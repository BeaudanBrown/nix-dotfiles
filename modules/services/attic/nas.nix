{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.custom.atticCache;
  domain = "attic.bepis.lol";
  portKey = "attic";
in
{
  custom.atticCache.upload.enable = true;

  custom.ports.requests = [ { key = portKey; } ];

  hostedServices = [
    {
      inherit domain;
      upstreamPort = toString config.custom.ports.assigned.${portKey};
      tailnet = true;
      webSockets = false;
    }
  ];

  services.atticd = {
    enable = true;
    mode = "monolithic";
    package = pkgs.attic-server;
    environmentFile = config.sops.secrets."atticd/env".path;
    settings = {
      listen = "127.0.0.1:${toString config.custom.ports.assigned.${portKey}}";
      allowed-hosts = [ domain ];
      "api-endpoint" = "${cfg.endpoint}/";

      # Keep Attic's SQLite metadata and chunk storage on the boot NVMe/Btrfs
      # filesystem. On nas, /var/lib is mounted from the slower ZFS pool, while
      # /var/cache inherits from / on the NVMe boot drive. This cache is
      # rebuildable performance data, so /var/cache is a better semantic fit
      # than durable service state.
      database.url = "sqlite:///var/cache/atticd/server.db?mode=rwc";
      storage = {
        type = "local";
        path = "/var/cache/atticd/storage";
      };

      # Attic has no hard byte-size quota in server config. Use time-based GC
      # to keep boot-drive usage bounded-ish: objects are eligible once they
      # have not been accessed for 90 days. Per-cache retention can still be
      # overridden with `attic cache configure fleet --retention-period ...`.
      "garbage-collection" = {
        interval = "1 day";
        "default-retention-period" = "90 days";
      };
    };
  };

  systemd.services.atticd.serviceConfig.CacheDirectory = [
    "atticd"
    "atticd/storage"
  ];

  sops.secrets."atticd/env" = {
    sopsFile = lib.custom.sopsFileForModule __curPos.file;
    mode = "0400";
    restartUnits = [ "atticd.service" ];
  };
}
