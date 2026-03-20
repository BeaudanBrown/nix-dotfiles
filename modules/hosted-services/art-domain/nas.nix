{
  config,
  ...
}:
let
  domain = "art.bepis.lol";
  portKey = "art-domain";
in
{
  hostedServices = [
    {
      inherit domain;
      upstreamPort = toString config.custom.ports.assigned.${portKey};
    }
  ];

  custom.ports.requests = [ { key = portKey; } ];

  services.art-domain = {
    enable = true;
    port = config.custom.ports.assigned.${portKey};
  };
}
