{
  lib,
  inputs,
  config,
  host,
  ...
}:
let
  roots = [
    "common"
    "work"
  ];
in
{
  imports =
    [
      ./hardware.nix

      inputs.sops-nix.nixosModules.sops
      inputs.nixvim.nixosModules.nixvim
      inputs.stylix.nixosModules.stylix
      inputs.home-manager.nixosModules.home-manager
    ]
    ++ (lib.custom.importAll {
      inherit host roots;
      spec = config.hostSpec;
    });

  hostSpec = {
    username = "beau";
    hostName = "laptop";
    email = "beaudan.brown@gmail.com";
    wifi = true;
    userFullName = "Beaudan Brown";
    sshPort = 8023;
  };

  system.stateVersion = "23.05";
}
