{ config, ... }:
{
  users.users.${config.hostSpec.username}.extraGroups = [ "networkmanager" ];
  networking = {
    # nameservers = [
    #   "1.1.1.1"
    #   "1.0.0.1"
    # ];
    wireless.enable = false;
    hostName = config.hostSpec.hostName;

    networkmanager = {
      enable = true;
    };
  };
}
