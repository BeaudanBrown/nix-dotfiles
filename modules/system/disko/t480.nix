{ ... }:
{
  disko.devices = (
    import ./btrfs_luks.nix {
      deviceName = "/dev/disk/by-id/nvme-eui.5cd2e42a81a83ae4";
      swapSize = "16G";
    }
  );
}
