{
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
    inputs.nix-index-database.nixosModules.default
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t480
    {
      home-manager = {
        extraSpecialArgs = { };
        backupFileExtension = "backup";
      };
    }
  ]
  ++ (import ../../generated/imports/t480.nix);

  thisHost = host;

  services.tlp = {
    enable = true;
  };

  services.fwupd.enable = true;

  system.stateVersion = "25.05";
}
