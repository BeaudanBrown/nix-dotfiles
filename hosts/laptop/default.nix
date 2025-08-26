{
  lib,
  inputs,
  host,
  nixpkgsStable,
  ...
}:
let
  roots = [
    "minimal"
    "common"
    "network" # Tailnet + Kitty etc
    "main" # Main machines: desktop, laptop, server
    "work"
  ];
in
{
  imports = [
    ./hardware.nix

    inputs.sops-nix.nixosModules.sops
    inputs.nixvim.nixosModules.nixvim
    inputs.stylix.nixosModules.stylix
    inputs.disko.nixosModules.disko
    inputs.home-manager.nixosModules.home-manager
  ]
  ++ (lib.custom.importAll {
    inherit host roots;
    extraSpecialArgs = { inherit nixpkgsStable; };
  });

  hostSpec = {
    username = "beau";
    hostName = host;
    tailIP = "100.64.0.2";
    email = "beaudan.brown@gmail.com";
    wifi = true;
    userFullName = "Beaudan Brown";
  };

  system.stateVersion = "25.05";
}
