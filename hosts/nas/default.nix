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
    "server"
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
      # inputs.arion.nixosModules.arion
      inputs.home-manager.nixosModules.home-manager
    ]
    ++ (lib.custom.importAll {
      inherit host roots;
      spec = config.hostSpec;
    });

  nix.settings.cores = 8;

  hostSpec = {
    username = "beau";
    hostName = host;
    email = "beaudan.brown@gmail.com";
    wifi = true;
    userFullName = "Beaudan Brown";
    sshPort = 22;
  };

  system.stateVersion = "25.05";
}
