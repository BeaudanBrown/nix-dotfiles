{ lib, ... }:
{
  config = {
    networking.networkmanager = {
      enable = true;
      wifi.backend = "iwd";
    };
    networking = {
      nameservers = [
      ];
      wireless.enable = lib.mkForce false;
      wireless.iwd = {
        enable = true;
        settings.General.EnableNetworkConfiguration = false;
        settings.General.AddressRandomization = "once";
      };
    };
  };
}
