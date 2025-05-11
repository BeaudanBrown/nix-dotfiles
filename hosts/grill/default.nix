{
  lib,
  inputs,
  config,
  host,
  ...
}:
let
  roots = [
    "minimal"
    "common"
    "work"
    "gaming"
  ];
in
{
  imports =
    [
      ./hardware.nix

      inputs.sops-nix.nixosModules.sops
      inputs.nixvim.nixosModules.nixvim
      inputs.stylix.nixosModules.stylix
      inputs.disko.nixosModules.disko
      inputs.home-manager.nixosModules.home-manager
    ]
    ++ (lib.custom.importAll {
      inherit host roots;
      spec = config.hostSpec;
    });

  nix.settings.cores = 12;
  hardware.bluetooth.enable = true;

  hostSpec = {
    username = "beau";
    hostName = host;
    email = "beaudan.brown@gmail.com";
    wifi = true;
    userFullName = "Beaudan Brown";
    sshPort = 8022;
  };

  boot = {
    supportedFilesystems = [ "ntfs" ];
  };

  system.stateVersion = "25.05";
}
