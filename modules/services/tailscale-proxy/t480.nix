{ config, lib, ... }:
let
  portKey = "tailscale-proxy/http";
  port = config.custom.ports.assigned.${portKey};
  proxy = "http://127.0.0.1:${toString port}";
in
{
  imports = [ ./runtime.nix ];

  custom.ports.requests = [ { key = portKey; } ];

  sops.secrets."tailscale-proxy/password" = {
    # Populate secrets/t480.yaml with the SAME password as secrets/nas.yaml.
    sopsFile = lib.custom.sopsFileForModule __curPos.file;
    owner = "sing-box";
    group = "sing-box";
    mode = "0400";
    restartUnits = [ "sing-box.service" ];
  };

  services.sing-box.settings = {
    inbounds = [
      {
        type = "http";
        tag = "tailscaled-local";
        listen = "127.0.0.1";
        listen_port = port;
      }
    ];
    outbounds = [
      {
        type = "naive";
        tag = "nas-proxy";
        server = "proxy.bepis.lol";
        server_port = 443;
        username = "t480";
        password._secret = config.sops.secrets."tailscale-proxy/password".path;
        quic = false;
        tls = {
          enabled = true;
          server_name = "proxy.bepis.lol";
        };
      }
    ];
    route.final = "nas-proxy";
  };

  # Only the daemon uses the proxy. No TUN, system-wide proxy variables,
  # routing changes, browser settings, or changes to the login server.
  systemd.services.tailscaled = {
    wants = [ "sing-box.service" ];
    after = [ "sing-box.service" ];
    environment = {
      HTTP_PROXY = proxy;
      HTTPS_PROXY = proxy;
      NO_PROXY = "localhost,127.0.0.1,::1";
      # Pinned Tailscale supports this internal knob; recheck on upgrades.
      TS_FORCE_NOISE_443 = "true";
    };
  };
}
