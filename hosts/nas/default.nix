{
  lib,
  inputs,
  config,
  host,
  nixpkgsStable,
  ...
}:
let
  roots = [
    "minimal"
    "common"
    "network"
    "server"
  ];
in
{
  imports = [
    ./hardware.nix

    inputs.sops-nix.nixosModules.sops
    inputs.nixvim.nixosModules.nixvim
    inputs.stylix.nixosModules.stylix
    inputs.disko.nixosModules.disko
    inputs.authentik-nix.nixosModules.default
    inputs.home-manager.nixosModules.home-manager
  ]
  ++ (lib.custom.importAll {
    inherit host roots;
    spec = config.hostSpec;
    extraSpecialArgs = { inherit nixpkgsStable; };
  });

  nix.settings.cores = 8;

  hostSpec = {
    username = "beau";
    hostName = host;
    email = "beaudan.brown@gmail.com";
    wifi = true;
    userFullName = "Beaudan Brown";
    sshPort = 8022;
  };

  system.stateVersion = "25.05";
}
