{ config, ... }:
let
  domain = "support.bepis.lol";
  portKey = "meshcentral";
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

  services.meshcentral = {
    enable = true;
    settings = {
      settings = {
        Cert = domain;
        Port = config.custom.ports.assigned.${portKey};
        aliasPort = 443;
        TlsOffload = "127.0.0.1";
        WANonly = false;
      };
      domains."" = {
        certUrl = "https://${domain}/";
      };
    };
  };
}
