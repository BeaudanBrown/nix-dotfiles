{
  config,
  lib,
  pkgs,
  ...
}:
let
  portKey = "wake-grill";
  port = toString config.custom.ports.assigned.${portKey};
  grill = config.hostSpecs.grill;
  knownHosts = pkgs.writeText "grill-unlock-known-hosts" (
    "grill-wake-unlock ${lib.removeSuffix "\n" (builtins.readFile ./grill-host.pub)}\n"
  );
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

  sops.secrets = {
    "wake-grill/unlock-token" = {
      sopsFile = lib.custom.sopsFileForModule __curPos.file;
      restartUnits = [ "wake-grill.service" ];
    };
    "wake-grill/ssh-private-key" = {
      sopsFile = lib.custom.sopsFileForModule __curPos.file;
      restartUnits = [ "wake-grill.service" ];
    };
  };

  systemd.services.wake-grill = {
    description = "Grill Wake-on-LAN and unlock relay";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = lib.escapeShellArgs [
        "${pkgs.python3}/bin/python3"
        "${./relay.py}"
        port
        "${pkgs.openssh}/bin/ssh"
        grill.tailIP
        (toString grill.sshPort)
        grill.username
        "${knownHosts}"
      ];
      LoadCredential = [
        "unlock-token:${config.sops.secrets."wake-grill/unlock-token".path}"
        "ssh-private-key:${config.sops.secrets."wake-grill/ssh-private-key".path}"
      ];
      DynamicUser = true;
      NoNewPrivileges = true;
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_UNIX"
      ];
      Restart = "on-failure";
    };
  };
}
