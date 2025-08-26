{ config, ... }:
let
  domain = "home.bepis.lol";
  portKey = "homeassistant";
in
{
  custom.ports.requests = [ { key = portKey; } ];

  hostedServices = [
    {
      inherit domain;
      upstreamHost = config.services.home-assistant.config.http.server_host;
      upstreamPort = toString config.services.home-assistant.config.http.server_port;
      # tailnet = true;
      webSockets = true;
    }
  ];
  services.home-assistant = {
    enable = true;
    extraComponents = [
      "esphome"
      "met"
      "radio_browser"
      "homeassistant_hardware"
      "zha"
      "google_translate"
      "smlight"
    ];
    config = {
      http = {
        server_host = "127.0.0.1";
        trusted_proxies = [
          "127.0.0.1"
          "::1"
        ];
        use_x_forwarded_for = true;
      };
      default_config = { };
      frontend = { };
    };
  };
}
