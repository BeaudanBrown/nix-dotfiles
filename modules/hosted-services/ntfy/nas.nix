{
  config,
  lib,
  ...
}:
let
  domain = "ntfy.bepis.lol";
  portKey = "ntfy";
in
{
  custom.ports.requests = [ { key = portKey; } ];
  hostedServices = [
    {
      inherit domain;
      tailnet = true;
      upstreamHost = "127.0.0.1";
      upstreamPort = toString config.custom.ports.assigned.${portKey};
      webSockets = true;
    }
  ];

  # Deliver streaming subscription responses immediately through the shared proxy.
  services.nginx.virtualHosts.${domain}.locations."/".extraConfig = ''
    proxy_buffering off;
  '';

  services.ntfy-sh = {
    enable = true;
    environmentFile = config.sops.secrets."ntfy/auth-env".path;
    settings = {
      base-url = "https://${domain}";
      listen-http = "127.0.0.1:${toString config.custom.ports.assigned.${portKey}}";
      behind-proxy = true;
      auth-default-access = "deny-all";
      auth-access = [
        # UnifiedPush application servers cannot authenticate to the distributor.
        # Tailnet reachability is still required; anonymous subscriptions are denied.
        "*:up*:write-only"
        "phone:up*:read-only"
        "phone:test:read-write"
      ];
      enable-login = true;
      enable-signup = false;
      enable-reservations = false;
      cache-duration = "12h";
      # No attachment storage, Firebase credentials or upstream ntfy.sh forwarding.
      attachment-cache-dir = "";
      upstream-base-url = "";
      # Avoid requiring an active subscriber before accepting a UnifiedPush push.
      visitor-subscriber-rate-limiting = false;
    };
  };

  # Synapse's HTTP push client blocks CGNAT/private addresses by default. Keep
  # that blocklist and allow only NAS's tailnet IPv4, not the whole tailnet.
  # This is IP-scoped, not limited to this hostname, port or URL.
  services.matrix-synapse.settings.ip_range_whitelist = [ "${config.hostSpec.tailIP}/32" ];

  sops.secrets."ntfy/auth-env" = {
    sopsFile = lib.custom.sopsFileForModule __curPos.file;
    owner = "root";
    mode = "0400";
    restartUnits = [ "ntfy-sh.service" ];
    # NTFY_AUTH_USERS='phone:<bcrypt password hash>:user'
    # The plaintext password is entered only into the phone/password manager.
  };
}
