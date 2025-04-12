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
      "modules/nixos/work"
      "modules/nixos/nix-laptop"
    ]);

  hostSpec = {
    username = "beau";
    hostName = "grill";
    email = "beaudan.brown@gmail.com";
    wifi = true;
    userFullName = "Beaudan Brown";
    sshPort = 8023;
  };

  home-manager = {
    backupFileExtension = "backup";
    users.beau.imports = (map lib.custom.relativeToRoot [
      "modules/home/common"
      "modules/home/work"
      "modules/home/nix-laptop"
    ]);
  };

  nix.settings.cores = 8;
  networking.hostName = "nix-laptop";
  system.stateVersion = "23.05";
}
