{ config, ... }:
{
  users.users.${config.hostSpec.username}.extraGroups = [ "networkmanager" ];

  networking = {
    networkmanager.enable = true;
    usePredictableInterfaceNames = false;
    useDHCP = false;
    interfaces.eth0.useDHCP = true;
    hostName = config.hostSpec.hostName;
    enableIPv6 = false;
  };
}
