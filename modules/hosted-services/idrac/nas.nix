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
      # Brick tail IP
      dnsTarget = "100.64.0.12";
      upstreamPort = "80";
      tailnet = true;
      webSockets = false;
      doNginx = false;
    }
  ];
}
