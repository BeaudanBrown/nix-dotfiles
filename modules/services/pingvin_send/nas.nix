{ config, ... }:
{
  hostedServices = [
    {
      domain = "send.bepis.lol";
      upstreamPort = toString config.services.pingvin-share.frontend.port;
    }
  ];
  # TODO: make the port selection more robust
  services.pingvin-share = {
    enable = true;
    frontend.port = 9999;
    backend.port = 10000;
  };
}
