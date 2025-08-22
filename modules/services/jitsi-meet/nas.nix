{ config, ... }:
let
  domain = "meet.bepis.lol";
  port = 5280;
in
{
  hostedServices = [
    {
      inherit domain;
      upstreamHost = config.services.jitsi-meet.host;
      upstreamPort = toString port;
      webSockets = true;
    }
  ];

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
