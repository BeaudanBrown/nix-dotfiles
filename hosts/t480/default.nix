{
  lib,
  inputs,
  host,
  nixpkgsStable,
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
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t480
  ]
  ++ (lib.custom.importAll {
    inherit host roots;
    extraSpecialArgs = { inherit nixpkgsStable; };
  });

  thisHost = host;

  services.tlp = {
    enable = true;
  };

  services.fwupd.enable = true;

  system.stateVersion = "25.05";
}
