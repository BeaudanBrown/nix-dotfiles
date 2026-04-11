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
    {
      home-manager = {
        extraSpecialArgs = { };
        backupFileExtension = "backup";
      };
    }
  ]
  ++ (import ../../generated/imports/rozzy.nix);

  services.qemuGuest.enable = true;

  nix.settings.cores = 4;

  thisHost = host;

  system.stateVersion = "25.11";
}
