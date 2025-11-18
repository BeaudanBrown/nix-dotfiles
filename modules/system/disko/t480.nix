{ ... }:
{
  disko.devices = (
    import ./btrfs_luks.nix {
      deviceName = "/dev/disk/by-id/nvme-eui.6479a7a810000071";
      swapSize = "16G";
    }
  );
}
