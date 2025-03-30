{
  pkgs,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
{
  imports = [ ./hardware.nix ];

  dotfiles.suites.core.enable = true;
  dotfiles.suites.laptop.enable = true;

  nix.settings.cores = 8;
  networking.hostName = "nix-laptop";
  system.stateVersion = "23.05";
}
