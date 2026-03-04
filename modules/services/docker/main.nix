{ config, lib, ... }:
{
  users.users.${config.hostSpec.username}.extraGroups = [ "docker" ];
  virtualisation = {
    docker = {
      enable = true;
      autoPrune = {
        enable = true;
      };
    };
  };

  systemd.tmpfiles.rules = [
    "d ${config.hostSpec.home}/.docker 0700 ${config.hostSpec.username} users - -"
  ];

  sops.secrets."docker-registry/config" = {
    sopsFile = lib.custom.sopsFileForModule __curPos.file;
    mode = "0600";
    owner = config.hostSpec.username;
    inherit (config.users.users.${config.hostSpec.username}) group;
    path = "${config.hostSpec.home}/.docker/config.json";
  };
}
