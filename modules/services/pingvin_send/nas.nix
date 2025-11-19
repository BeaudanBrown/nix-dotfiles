{ config, ... }:
let
  domain = "send.bepis.lol";
  keyFrontend = "pingvin/frontend";
  keyBackend = "pingvin/backend";
in
{
  custom.ports.requests = [
    { key = keyFrontend; }
    { key = keyBackend; }
  ];

  hostedServices = [
    {
      inherit domain;
      upstreamPort = toString config.custom.ports.assigned.${keyFrontend};
    }
  ];

  services.pingvin-share = {
    enable = false;
    frontend.port = config.custom.ports.assigned.${keyFrontend};
    backend.port = config.custom.ports.assigned.${keyBackend};
  };
}
