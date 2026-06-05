{
  lib,
  inputs,
  host,
  ...
}:
{
  imports = [
    ./hardware.nix

    inputs.sops-nix.nixosModules.sops
    inputs.nixvim.nixosModules.nixvim
    inputs.stylix.nixosModules.stylix
    inputs.disko.nixosModules.disko
    inputs.home-manager.nixosModules.home-manager
    inputs.nixos-hardware.nixosModules.raspberry-pi-4
    ./pinned-running-kernel.nix
    inputs."pi-harness".nixosModules.pi-harness
    {
      home-manager = {
        extraSpecialArgs = { };
        backupFileExtension = "backup";
      };
    }
  ]
  ++ (import ../../generated/imports/pi4.nix);

  boot.loader.systemd-boot.enable = lib.mkForce false;

  thisHost = host;

  system.stateVersion = "25.05";
}
