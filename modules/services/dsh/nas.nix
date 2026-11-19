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
    # Only the index gets an interactive 401. API, assets and WebSockets
    # retain their original responses. Preserve the query on valid token links.
    locations."= /" =
      let
        backend = config.services.nginx.virtualHosts.${domain}.locations."/";
      in
      {
        inherit (backend) proxyPass recommendedProxySettings;
        extraConfig = backend.extraConfig + ''
          proxy_intercept_errors on;
          error_page 401 =401 @dsh_login_retry;
        '';
      };
    locations."@dsh_login_retry".extraConfig = ''
      default_type text/html;
      add_header Cache-Control "no-store" always;
      add_header Referrer-Policy "no-referrer" always;
      # A document-initiated navigation can carry the Strict cookie omitted on
      # cold PWA launch. Only retry a bare URL: never replay a token or loop.
      return 401 '<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>DSH sign-in</title><script>if (location.search === "") location.replace("/?pwa_retry=1");</script><h1>DSH authentication required</h1><p><a href="/">Continue to DSH</a></p><p>If this page returns, this app needs a valid DSH login.</p></html>';
    '';
    locations."/".recommendedProxySettings = false;
    locations."/".extraConfig = lib.mkForce ''
      proxy_set_header Host $host;
      proxy_cookie_flags ~ secure httponly samesite=strict;
      proxy_read_timeout 3600s;
      proxy_send_timeout 3600s;
      proxy_request_buffering off;
      proxy_buffering off;
    '';
  };
}
