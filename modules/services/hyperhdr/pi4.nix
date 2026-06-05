{
  config,
  lib,
  pkgs,
  ...
}:
let
  username = config.hostSpec.username;
  user = config.users.users.${username};
in
{
  environment.systemPackages = with pkgs; [
    hyperhdr
    libraspberrypi
    usbutils
    v4l-utils
  ];

  users.users.${username}.extraGroups = [
    "dialout"
    "video"
  ];

  networking.firewall = {
    allowedTCPPorts = [
      8090 # HTTP web UI
      8092 # HTTPS web UI
      19400 # FlatBuffers server
      19444 # JSON API
    ];
    allowedUDPPorts = [
      1900 # SSDP discovery
    ];
  };

  systemd.services.hyperhdr = {
    description = "HyperHDR ambient lighting service";
    documentation = [ "https://wiki.hyperhdr.eu/" ];
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];

    serviceConfig = {
      User = username;
      Group = user.group;
      SupplementaryGroups = [
        "dialout"
        "video"
      ];
      StateDirectory = "hyperhdr";
      StateDirectoryMode = "0750";
      ExecStart = "${lib.getExe pkgs.hyperhdr} --service --userdata /var/lib/hyperhdr";
      Restart = "on-failure";
      RestartSec = 2;
      TimeoutStopSec = 5;
      KillMode = "mixed";
    };
  };
}
