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
    inputs.home-manager.nixosModules.home-manager
    # "${inputs.loom}/infra/nixos-modules/loom-server.nix"
    # "${inputs.loom}/infra/nixos-modules/loom-web.nix"
    # "${inputs.loom}/infra/nixos-modules/k3s.nix"
  ]
  ++ (lib.custom.importAll {
    inherit host roots;
    extraSpecialArgs = { };
  });

  nix.settings.cores = 16;

  hostSpec = {
    username = "mikaerem";
    hostName = host;
    tailIP = "100.64.0.12";
    email = "mccarm110@gmail.com";
    wifi = false;
    userFullName = "Mika";
  };

  system.stateVersion = "25.11";
}
