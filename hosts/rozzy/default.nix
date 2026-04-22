{
  inputs,
  host,
  pkgs,
  ...
}:
{
  imports = [
    ./hardware.nix

    inputs.sops-nix.nixosModules.sops
    inputs.nixvim.nixosModules.nixvim
    inputs.stylix.nixosModules.stylix
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

  nix.settings.cores = 2;

  thisHost = host;

  environment.systemPackages = with pkgs; [
    wget
    tree
    inetutils
    mtr
    sysstat
  ];

  system.stateVersion = "25.11";
}
