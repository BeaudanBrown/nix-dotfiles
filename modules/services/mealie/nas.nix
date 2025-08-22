{ config, ... }:
let
  domain = "meals.bepis.lol";
in
{
  hostedServices = [
    {
      inherit domain;
      upstreamHost = config.services.mealie.listenAddress;
      upstreamPort = toString config.services.mealie.port;
      webSockets = true;
    }
  ];

  services.mealie = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = 9001;
    # See https://docs.mealie.io/documentation/getting-started/installation/backend-config/
    settings = {
      DB_ENGINE = "sqlite";
      BASE_URL = "https://${domain}";
      ALLOW_SIGNUP = false;
      TZ = config.time.timeZone;
    };
  };
}
