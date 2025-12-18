{
  lib,
  inputs,
  host,
  ...
}:
let
  roots = [
    "minimal"
    "common"
    "network" # Tailnet + Kitty etc
    "main" # Main machines: desktop, laptop, server
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
    inputs.copyparty.nixosModules.default
    inputs.home-manager.nixosModules.home-manager
    inputs.joan-flash.nixosModules.default
  ]
  ++ (lib.custom.importAll {
    inherit host roots;
    extraSpecialArgs = { };
  });

  nix.settings.cores = 8;

  hostSpec = {
    username = "beau";
    hostName = host;
    tailIP = "100.64.0.4";
    email = "beaudan.brown@gmail.com";
    wifi = true;
    userFullName = "Beaudan Brown";
  };

  system.stateVersion = "25.05";
}
