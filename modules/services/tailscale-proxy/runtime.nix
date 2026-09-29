{
  lib,
  pkgs,
  ...
}:
{
  # Shared only by the explicit NAS/t480 modules, not the client root.
  services.sing-box = {
    enable = true;
    # The shared unstable overlay includes Naive outbound and Cronet support.
    package = pkgs.unstable.sing-box;
    settings = {
      log.level = "warn";
      dns.servers = [
        {
          type = "local";
          tag = "bootstrap";
        }
      ];
      route.default_domain_resolver = "bootstrap";
    };
  };

  # This is a userspace TCP proxy, not a TUN/router. Remove the upstream
  # service's broad networking, ptrace and DAC-bypass capabilities.
  systemd.services.sing-box.serviceConfig = {
    AmbientCapabilities = lib.mkForce "";
    CapabilityBoundingSet = lib.mkForce "";
    NoNewPrivileges = true;
    PrivateTmp = true;
    ProtectHome = true;
    ProtectSystem = "strict";
    RestrictAddressFamilies = [
      "AF_INET"
      "AF_INET6"
      "AF_NETLINK" # sing-box inspects host network state during startup.
      "AF_UNIX"
    ];
  };
}
