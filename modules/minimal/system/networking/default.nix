{ config, ... }:
{
  users.users.${config.hostSpec.username}.extraGroups = [ "networkmanager" ];
  networking = {
    wireless.enable = false;
    hostName = config.hostSpec.hostName;
    nameservers = [
      "1.1.1.1"
      "1.0.0.1"
    ];
    networkmanager = {
      enable = true;
    };
  };
}
