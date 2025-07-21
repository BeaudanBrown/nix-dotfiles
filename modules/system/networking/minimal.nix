{ config, ... }:
{
  users.users.${config.hostSpec.username}.extraGroups = [ "networkmanager" ];
  networking = {
    wireless.enable = false;
    hostName = config.hostSpec.hostName;

    networkmanager = {
      enable = true;
    };
  };
}
