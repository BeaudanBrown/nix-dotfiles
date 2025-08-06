{ lib, ... }:
{
  boot = {
    supportedFilesystems = [
      "ntfs"
    ];
    # Issues with zfs in latest kernel
    # kernelPackages = pkgs.linuxPackages_latest;
    kernelParams = [
      "snd-intel-dspcfg.dsp_driver=1"
      "kvm.enable_virt_at_load=0"
    ];
    loader = {
      efi.canTouchEfiVariables = true;
      systemd-boot = {
        enable = true;
        configurationLimit = 5;
      };
      timeout = lib.mkForce 1;
    };
  };
}
