{ lib, ... }:
{
  boot = {
    supportedFilesystems = [
      "ntfs"
    ];
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
    kernel.sysctl = {
      # Try to make tethered traffic look untethered
      "net.ipv4.ip_default_ttl" = 65;
      "net.ipv6.conf.default.hop_limit" = 65;
      "net.ipv6.conf.enp0s20f0u2.hop_limit" = 65;
    };
  };
}
