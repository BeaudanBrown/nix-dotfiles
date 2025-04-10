{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    networkmanager-openconnect
    networkmanagerapplet
    openconnect
  ];
  networking = {
    networkmanager = {
      plugins = [
        pkgs.networkmanager-openconnect
      ];
    };
  };
}
