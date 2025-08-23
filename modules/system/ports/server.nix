{ ... }:
{
  # Extend the protected list with static ports in use on server hosts.
  # This avoids dynamic allocations ever choosing these, preventing conflicts.
  custom.ports.reserved = [
    # DNS (CoreDNS / system resolvers)
    53

    # Standard HTTP/HTTPS served by nginx
    80
    443

    # Common alternative HTTP/HTTPS
    8080
    8443

    # Developer ports commonly in use; keep them free
    3000
    3001
    3002

    # Immich machine-learning service (static within module)
    3003

    # Jitsi/Prosody HTTP endpoint used by your deployment
    5280

    # Authentik application (authentik-nix)
    9000
  ];
}
