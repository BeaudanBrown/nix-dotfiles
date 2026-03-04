{ ... }:
let
  domain = "idrac.bepis.lol";
  portKey = "idrac";
in
{
  custom.ports.requests = [ { key = portKey; } ];

  hostedServices = [
    {
      inherit domain;
      upstreamHost = "192.168.1.104";
      upstreamPort = "80";
      tailnet = true;
      webSockets = true;
    }
  ];
}
