{ config, ... }:
let
  sessionDir = "${config.syncedState.root}/pi/sessions";
in
{
  services.pi-harness.sessionDirectory = sessionDir;

  systemd.tmpfiles.rules = [
    "d ${config.syncedState.root}/pi 0700 ${config.hostSpec.username} users - -"
    "d ${sessionDir} 0700 ${config.hostSpec.username} users - -"
  ];
}
