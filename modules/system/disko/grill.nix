{ ... }:
{
  disko.devices = (
    import ./btrfs.nix {
      deviceName = "/dev/disk/by-id/wwn-0x5002538e4985d990";
      swapSize = "16G";
    }
  );
}
