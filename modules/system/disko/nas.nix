{ ... }:
{
  disko.devices = import ./btrfs.nix {
      deviceName = "/dev/disk/by-id/wwn-0x5002538e00000000";
      swapSize = "16G";
    } // {
      zpool = {
        pool1 = {
          type = "zpool";
          datasets = {
            "pool1" = {
              type = "zfs_fs";
              mountpoint = "/pool1";
              options.mountpoint = "legacy";
            };
          };
        };
      };
    };
}
