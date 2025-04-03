{ lib, inputs, ... }:
{
  imports = [
    ./hardware.nix

    inputs.sops-nix.nixosModules.sops
    inputs.nixvim.nixosModules.nixvim
    inputs.stylix.nixosModules.stylix
    inputs.home-manager.nixosModules.home-manager
  ] ++ (map lib.custom.relativeToRoot [
      "modules/nixos/common"
      "modules/nixos/grill"
    ]);

  hostSpec = {
    username = "beau";
    hostName = "grill";
    email = "beaudan.brown@gmail.com";
    wifi = true;
    userFullName = "Beaudan Brown";
    sshPort = 8022;
  };

  home-manager = {
    backupFileExtension = "backup";
    users.beau.imports = (map lib.custom.relativeToRoot [
      "modules/home/common"
      "modules/home/grill"
    ]);
  };

  boot.initrd.kernelModules = [ "amdgpu" ];
  nix.settings.cores = 12;
  networking.hostName = "grill";
  system.stateVersion = "23.05";
}
