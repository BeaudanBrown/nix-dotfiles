{ config, ... }:
{
  users.users.${config.hostSpec.username}.extraGroups = [ "networkmanager" ];
  services.resolved = {
    enable = true;
    fallbackDns = [
      "1.1.1.1"
      "1.0.0.1"
    ];
  };
  networking = {
    wireless.enable = false;
    hostName = config.hostSpec.hostName;

    networkmanager = {
      enable = true;
      dns = "systemd-resolved";
    };
  };
}
