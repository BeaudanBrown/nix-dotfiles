{ config, ... }:
let
  domain = "drop.bepis.lol";
  portKey = "pairdrop";
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

  services.pairdrop = {
    enable = true;
    port = config.custom.ports.assigned.${portKey};
    environment = {
      WS_FALLBACK = true;
    };
  };
}
