{ config, ... }:
{
  services.nginx.virtualHosts."send.bepis.lol" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString config.services.pingvin-share.frontend.port}";
    };
  };
  # TODO: make the port selection more robust
  services.pingvin-share = {
    enable = true;
    frontend.port = 9999;
    backend.port = 10000;
  };
}
