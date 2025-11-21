{ config, ... }:
let
  domain = "send.bepis.lol";
  portKey = "send";
in
{
  custom.ports.requests = [ { key = portKey; } ];

  hostedServices = [
    {
      inherit domain;
      upstreamPort = toString config.custom.ports.assigned.${portKey};
      webSockets = true;
    }
  ];

  # Send (Firefox Send fork) - file sharing service
  services.send = {
    enable = true;
    host = "127.0.0.1";
    port = config.custom.ports.assigned.${portKey};
    baseUrl = "https://${domain}";

    redis = {
      createLocally = true;
    };

    environment = {
      # File expiration settings
      EXPIRE_TIMES_SECONDS = "3600,86400,604800"; # 1 hour, 1 day, 1 week
      DEFAULT_EXPIRE_SECONDS = 86400; # Default: 1 day

      # File size limits
      MAX_FILE_SIZE = 2684354560; # 2.5 GB
      MAX_EXPIRE_SECONDS = 604800; # Max expiration: 1 week

      # Download limits
      MAX_DOWNLOADS = 100;
      DEFAULT_DOWNLOADS = 5;
    };
  };
}
