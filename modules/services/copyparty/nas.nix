{ config, inputs, ... }:
let
  domain = "cp.bepis.lol";
  portKey = "copyparty";
in
{
  custom.ports.requests = [ { key = portKey; } ];

  hostedServices = [
    {
      inherit domain;
      upstreamPort = toString config.custom.ports.assigned.${portKey};
      webSockets = false;
    }
  ];
  nixpkgs.overlays = [ inputs.copyparty.overlays.default ];

  services.copyparty = {
    enable = true;

    settings = {
      # Bind to localhost only - nginx handles external access
      i = "127.0.0.1";
      p = [ config.custom.ports.assigned.${portKey} ];

      # Reverse proxy configuration
      rproxy = 1;
      xff-hdr = "X-Forwarded-For";

      # Allow users to change passwords (for future auth)
      chpw = false;

      # Show HTML files inline
      ih = true;
    };

    volumes = {
      "/" = {
        path = "/pool1/public";

        # Anonymous read and write access
        access = {
          r = "*"; # Anyone can read/download
          w = "*"; # Anyone can write/upload
        };

        # Enhanced features
        flags = {
          # Database for search and indexing
          e2d = true; # Enable database
          e2dsa = true; # Use SQLite for database

          # Media features
          dedup = true; # Enable file deduplication

          # Auto-scan for new files every 15 minutes
          scan = 900;
        };
      };
    };
  };
}
