{
  lib,
  inputs,
  pkgs,
  ...
}:
rec {
  imports = lib.flatten [
    ./hardware.nix

    (map lib.custom.relativeToRoot [
      "modules/nixos/common"
      "modules/nixos/grill"
    ])

    inputs.sops-nix.nixosModules.sops
    inputs.nixvim.nixosModules.nixvim
    inputs.stylix.nixosModules.stylix
    inputs.home-manager.nixosModules.home-manager
    {
      home-manager.backupFileExtension = "backup";
      home-manager.users.beau.imports = lib.flatten [
        (map lib.custom.relativeToRoot [
          "modules/home/common"
          "modules/home/grill"
        ])
      ];
    }
  ];

  hostSpec = {
    username = "beau";
    hostName = "grill";
    email = "beaudan.brown@gmail.com";
    wifi = true;
    userFullName = "Beaudan Brown";
  };

  boot.initrd.kernelModules = [ "amdgpu" ];
  nix.settings.cores = 12;
  networking.hostName = "grill";
  system.stateVersion = "23.05";
}
