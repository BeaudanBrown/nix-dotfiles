{
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
{
  imports = [ ./hardware.nix ];

  dotfiles.suites.core.enable = true;
  dotfiles.suites.grill.enable = true;

  boot.initrd.kernelModules = [ "amdgpu" ];
  nix.settings.cores = 12;
  networking.hostName = "grill";
  system.stateVersion = "23.05";
}
