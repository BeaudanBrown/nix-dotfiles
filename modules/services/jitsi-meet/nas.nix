{ config, ... }:
let
  domain = "meet.bepis.lol";
  port = 5280;
in
{
  nixpkgs.config.permittedInsecurePackages = [
    "jitsi-meet-1.0.8043"
  ];
  hostedServices = [
    {
      inherit domain;
      upstreamHost = config.services.jitsi-meet.hostName;
      upstreamPort = toString port;
      doNginx = false;
    }
  ];

  services.nginx.virtualHosts.${domain} = {
    enableACME = false;
    forceSSL = true;
    useACMEHost = domain;
  };

  services.jitsi-meet = {
    enable = true;
    # nginx.enable = false;
    hostName = domain;
    config = {
      enableWelcomePage = false;
      defaultLang = "en";
    };
    interfaceConfig = {
      SHOW_JITSI_WATERMARK = false;
      SHOW_WATERMARK_FOR_GUESTS = false;
    };
  };
}
