{ configLib, ... }:
{
  imports =
  [
    ./hardware-configuration.nix
  ] ++ (map configLib.relativeToRoot [
    "nixos/common/core"
  ]);

  boot.initrd.kernelModules = [ "amdgpu" ];

  nix.settings.cores = 12;

  networking.hostName = "grill";

  programs.steam.enable = true;

  # https://wiki.nixos.org/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "23.05";
}
