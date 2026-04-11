{ ... }:
{
  disko.devices = (
    import ./btrfs.nix {
      deviceName = "/dev/sda";
      swapSize = "8G";
    }
  );
}
