{
  lib,
  inputs,
  host,
  ...
}:
let
  allHostsData = import ../../modules/host-spec/all-hosts.nix;
  roots = allHostsData.hostSpecs.${host}.roots;
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

  thisHost = host;

  system.stateVersion = "25.11";
}
