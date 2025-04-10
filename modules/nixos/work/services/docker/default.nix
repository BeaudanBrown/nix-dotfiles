{ config, ... }:
{
  users.users.${config.hostSpec.username}.extraGroups = [ "docker" ];
  virtualisation = {
    docker = {
      enable = true;
      autoPrune = { enable = true; };
    };
  };
}

