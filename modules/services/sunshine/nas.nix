{ config, lib, ... }:
let
  domain = "sunshine.bepis.lol";
in
{
  hostedServices = [
    {
      inherit domain;
      upstreamHost = config.hostSpecs.grill.tailIP;
      upstreamPort = "47990";
      tailnet = true;
      webSockets = true;
    }
  ];

  services.nginx.virtualHosts.${domain}.locations."/" = {
    proxyPass = lib.mkForce "https://${config.hostSpecs.grill.tailIP}:47990";
    extraConfig = ''
      # Deliberate: HTTPS inside authenticated Tailscale transport. Sunshine's
      # self-signed backend certificate is not independently verified here.
      proxy_ssl_verify off;
      proxy_buffering off;
    '';
  };
  # Sunshine retains Basic Auth and CSRF enforcement. No injected credentials,
  # public DNS registration, TLS passthrough, or extra authentication service.
}
