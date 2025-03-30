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
      "modules/nixos/nix-laptop"
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
          "modules/home/nix-laptop"
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

  nix.settings.cores = 8;
  networking.hostName = "nix-laptop";
  system.stateVersion = "23.05";
}
