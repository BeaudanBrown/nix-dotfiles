{
  config,
  ...
}:
let
  domain = "joan.bepis.lol";
  portKey = "joan";
in
{
  hostedServices = [
    {
      inherit domain;
      upstreamPort = toString config.custom.ports.assigned.${portKey};
    }
  ];
  custom.ports.requests = [ { key = portKey; } ];
  services.joan-flash = {
    enable = true;
    port = config.custom.ports.assigned.${portKey};
  };
}
