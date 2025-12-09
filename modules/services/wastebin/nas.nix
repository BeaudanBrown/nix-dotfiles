{ config, ... }:
let
  domain = "text.bepis.lol";
  portKey = "wastebin";
in
{
  custom.ports.requests = [ { key = portKey; } ];

  hostedServices = [
    {
      inherit domain;
      upstreamPort = toString config.custom.ports.assigned.${portKey};
      tailnet = false; # Public access
    }
  ];

  services.wastebin = {
    enable = true;
    stateDir = "/var/lib/wastebin";

    settings = {
      WASTEBIN_ADDRESS_PORT = "127.0.0.1:${toString config.custom.ports.assigned.${portKey}}";
      WASTEBIN_BASE_URL = "https://${domain}";

      # Database
      WASTEBIN_DATABASE_PATH = "/var/lib/wastebin/wastebin.db";

      # Performance tuning
      WASTEBIN_CACHE_SIZE = 100; # Cache 100 rendered syntax highlight items
      WASTEBIN_HTTP_TIMEOUT = 30; # 30 seconds timeout

      # Limits
      WASTEBIN_MAX_BODY_SIZE = 10485760; # 10 MB max paste size

      # UI customization
      WASTEBIN_TITLE = "text.bepis.lol";

      # Logging
      RUST_LOG = "info,tower_http=debug"; # Log requests/responses
    };

    # Optional: Add signing key and password salt for persistence
    # secretFile = config.sops.secrets."wastebin/env".path;
  };

  # Uncomment if you want persistent cookies and encrypted pastes
  # sops.secrets."wastebin/env" = { };
}
