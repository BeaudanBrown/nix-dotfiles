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
    inputs.authentik-nix.nixosModules.default
    inputs.copyparty.nixosModules.default
    inputs.home-manager.nixosModules.home-manager
    inputs.joan-flash.nixosModules.default
    "${inputs.loom}/infra/nixos-modules/loom-server.nix"
    "${inputs.loom}/infra/nixos-modules/loom-web.nix"
    "${inputs.loom}/infra/nixos-modules/k3s.nix"
  ]
  ++ (lib.custom.importAll {
    inherit host roots;
    extraSpecialArgs = { };
  });

  # Enable emulation for cross-compilation
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  nix.settings.cores = 8;

  thisHost = host;

  system.stateVersion = "25.05";
}
