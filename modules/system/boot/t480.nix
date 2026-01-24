{ lib, ... }:
{
  # Activate the swapfile created by disko for hibernation support
  # The swap is located on the encrypted btrfs subvolume at /.swapvol/swapfile
  swapDevices = [
    { device = "/.swapvol/swapfile"; }
  ];
  boot = {
    # Hibernation support
    kernelParams = [ "resume_offset=28058880" ];
    resumeDevice = "/dev/mapper/encrypted-nixos";
    loader = {
      systemd-boot.enable = lib.mkForce false;
      grub = {
        enable = true;
        device = "nodev";
        configurationLimit = 5;
      };
    };
  };
}
