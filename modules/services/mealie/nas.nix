{ config, ... }:
let
  domain = "meals.bepis.lol";
  portKey = "mealie";
in
{
  custom.ports.requests = [ { key = portKey; } ];

  hostedServices = [
    {
      inherit domain;
      upstreamHost = config.services.mealie.listenAddress;
      upstreamPort = toString config.custom.ports.assigned.${portKey};
      webSockets = true;
    }
  ];

  services.mealie = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = config.custom.ports.assigned.${portKey};
    # See https://docs.mealie.io/documentation/getting-started/installation/backend-config/
    settings = {
      DB_ENGINE = "sqlite";
      BASE_URL = "https://${domain}";
      TZ = config.time.timeZone;
    };
  };
}
