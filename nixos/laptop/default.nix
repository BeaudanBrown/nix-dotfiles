{ pkgs, configLib, ... }:
{
  imports =
  [
    ./hardware-configuration.nix
  ] ++ (map configLib.relativeToRoot [
    "nixos/common/core"
  ]);

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    kernelParams = [ "snd-intel-dspcfg.dsp_driver=1" ];
    loader.efi.canTouchEfiVariables = true;
  };

  nix.settings.cores = 12;

  networking.hostName = "nix-laptop";

  # https://wiki.nixos.org/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "23.05";
}
