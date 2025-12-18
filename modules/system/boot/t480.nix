{ ... }:
{
  # Hibernation support
  boot.resumeDevice = "/dev/mapper/encrypted-nixos";
  boot.kernelParams = [ "resume_offset=28058880" ];
  # Activate the swapfile created by disko for hibernation support
  # The swap is located on the encrypted btrfs subvolume at /.swapvol/swapfile
  swapDevices = [
    { device = "/.swapvol/swapfile"; }
  ];
}
