{ config, ... }:
{
  services.adguardhome = {
    enable = true;
    port = 3001;
  };
  services.nginx.virtualHosts."dns.bepis.lol" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      # This port is currently hard coded in the module
      proxyPass = "http://${config.services.immich.host}:${toString config.services.immich.port}";
    };
  };
}
