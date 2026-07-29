{ ... }:
{
  disko.devices = (
    import ./btrfs.nix {
      deviceName = "/dev/disk/by-id/wwn-0x5002538e4985d990";
      diskName = "grill";
      swapSize = "16G";
    }
  );
}
