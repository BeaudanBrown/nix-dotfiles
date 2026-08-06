{ config, ... }:
let
  user = config.hostSpec.username;
  home = config.hostSpec.home;
  synchronizedSessionRoot = "${config.syncedState.root}/pi/sessions";
  piAgentRoot = "${home}/.pi/agent";
  nativeSessionRoot = "${piAgentRoot}/sessions";
in
{
  systemd.tmpfiles.rules = [
    "d ${config.syncedState.root}/pi 0700 ${user} users - -"
    "d ${synchronizedSessionRoot} 0700 ${user} users - -"
    "d ${home}/.pi 0700 ${user} users - -"
    "d ${piAgentRoot} 0700 ${user} users - -"
    "d ${nativeSessionRoot} 0700 ${user} users - -"
  ];

  systemd.mounts = [
    {
      description = "Bind synchronized state over Pi's native session root";
      what = synchronizedSessionRoot;
      where = nativeSessionRoot;
      type = "none";
      options = "bind";
      wantedBy = [ "multi-user.target" ];
      after = [ "systemd-tmpfiles-setup.service" ];
      before = [ "syncthing.service" ];
    }
  ];
}
