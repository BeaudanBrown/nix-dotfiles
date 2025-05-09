{ ... }:
{
  disko.devices = (import ./btrfs.nix {
    deviceName = "/dev/disk/by-id/wwn-0x5002538e405f2c6d";
    swapSize = "16G";
  });
}
