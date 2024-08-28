{ inputs, pkgs, configLib, ... }:
{
  imports =
  [
    ./hardware-configuration.nix
  ] ++ (map configLib.relativeToRoot [
    "hosts/common/core"
  ]);

  programs.steam.enable = true;

  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelParams = [ "snd-intel-dspcfg.dsp_driver=1" ];
  boot.initrd.kernelModules = [ "amdgpu" ];
  boot.loader.efi.canTouchEfiVariables = true;
  networking.hostName = "grill";

  # https://wiki.nixos.org/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "23.05";
}
