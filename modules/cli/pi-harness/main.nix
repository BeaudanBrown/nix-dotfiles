{ config, ... }:
let
  sessionDir = "${config.syncedState.root}/pi/sessions";
in
{
  environment.sessionVariables.PI_CODING_AGENT_SESSION_DIR = sessionDir;

  systemd.tmpfiles.rules = [
    "d ${config.syncedState.root}/pi 0700 ${config.hostSpec.username} users - -"
    "d ${sessionDir} 0700 ${config.hostSpec.username} users - -"
  ];
}
