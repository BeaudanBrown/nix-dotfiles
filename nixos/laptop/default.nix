{ configLib, ... }:
{
  imports = (map configLib.relativeToRoot [
    "nixos/common/core"
  ]) ++ (configLib.scanPaths ./.);

  nix.settings.cores = 8;

  networking.hostName = "nix-laptop";

  # https://wiki.nixos.org/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "23.05";
}
