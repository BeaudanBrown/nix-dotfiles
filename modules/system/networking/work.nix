{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    networkmanager-openconnect
    networkmanagerapplet
    openconnect
  ];
  environment.etc = {
    "resolv.conf".text = "nameserver 1.1.1.1\n";
  };
  networking = {
    networkmanager = {
      plugins = [
        pkgs.networkmanager-openconnect
      ];
    };
  };
}
