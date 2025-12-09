{ config, ... }:
let
  domain = "l.bepis.lol";
  portKey = "chhoto-url";
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

  services.chhoto-url = {
    enable = true;

    settings = {
      port = config.custom.ports.assigned.${portKey};
      site_url = "https://${domain}";
      slug_style = "Pair"; # Use word pairs (e.g., "happy-panda") instead of random UIDs
    };

    # Optional: Add authentication via environment file
    # environmentFiles = [ config.sops.secrets."chhoto-url/env".path ];
  };

  # Uncomment if you want to add admin password protection
  # sops.secrets."chhoto-url/env" = { };
}
