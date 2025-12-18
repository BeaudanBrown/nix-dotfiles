{ ... }:
{
  disko.devices = (
    import ./btrfs_luks.nix {
      deviceName = "/dev/disk/by-id/nvme-eui.6479a7a810000071";
      swapSize = "42G"; # 40GB RAM + 2GB buffer for hibernation
    }
  );
}
