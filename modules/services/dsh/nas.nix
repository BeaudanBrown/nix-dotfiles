{ config, lib, ... }:
let
  domain = "dsg.bepis.lol";
in
{
  # Reuse NAS ingress, DNS and cloudflare/env. No DSH process or new secret here.
  hostedServices = [
    {
      inherit domain;
      upstreamHost = config.hostSpecs.grill.tailIP;
      upstreamPort = "3080";
      tailnet = true;
      webSockets = true;
    }
  ];

  services.nginx.virtualHosts.${domain} = {
    # Token-link URLs must not enter request/error logs.
    extraConfig = ''
      access_log off;
      error_log /dev/null;
    '';
    locations."/".recommendedProxySettings = false;
    locations."/".extraConfig = lib.mkForce ''
      proxy_set_header Host $http_host;
      proxy_cookie_flags ~ secure httponly samesite=strict;
      proxy_read_timeout 3600s;
      proxy_send_timeout 3600s;
      proxy_request_buffering off;
      proxy_buffering off;
    '';
  };
}
