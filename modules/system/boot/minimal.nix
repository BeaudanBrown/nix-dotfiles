{ pkgs, ... }:
{
  boot = {
    supportedFilesystems = [
      "ntfs"
      "zfs"
    ];
    kernelPackages = pkgs.linuxPackages_latest;
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
      # timeout = 1;
      # systemd-boot.enable = false;
      # grub = {
      #   enable = true;
      #   efiSupport = true;
      #   device = "nodev";
      #   configurationLimit = 5;
      # };
    };
  };
}
