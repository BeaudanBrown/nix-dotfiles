{ config, pkgs, ... }:
let
  portKey = "wake-grill";
  port = toString config.custom.ports.assigned.${portKey};
in
{
  custom.ports.requests = [ { key = portKey; } ];

  hostedServices = [
    {
      domain = "wake.bepis.lol";
      upstreamPort = port;
      tailnet = true;
    }
  ];

  systemd.services.wake-grill = {
    description = "Grill Wake-on-LAN relay";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.python3}/bin/python3 ${./relay.py} ${port}";
      DynamicUser = true;
      NoNewPrivileges = true;
      RestrictAddressFamilies = [ "AF_INET" ];
      Restart = "on-failure";
    };
  };
}
