{ ... }:
{
  disko.devices = (
    import ./btrfs.nix {
      deviceName = "/dev/disk/by-id/wwn-0x5001b448b7c23c3f";
      swapSize = "16G";
    }
  );
}
