{ configLib, ... }:
{
  imports =
  [
    ./hardware-configuration.nix
  ] ++ (map configLib.relativeToRoot [
    "nixos/common/core"
  ]);

  nix.settings.cores = 8;

  networking.hostName = "nix-laptop";

  # https://wiki.nixos.org/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "23.05";
}
