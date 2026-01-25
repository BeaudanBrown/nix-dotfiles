{ ... }:
{
  disko.devices = (
    import ./btrfs_2_drives.nix {
      deviceName = "/dev/disk/by-id/wwn-0x61866da062f86a003108cbd94806e297";
      secondDeviceName = "/dev/disk/by-id/wwn-0x61866da062f86a003108cca153f46d33";
      swapSize = "16G";
    }
  );
}
