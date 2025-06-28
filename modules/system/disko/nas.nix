{ ... }:
{
  services.zfs.autoScrub.enable = true;
  # The mountpoint is defined IMPERATIVELY by zfs
  # TODO: make disko handle this?
  # sudo zfs get -r mountpoint
  disko.devices = import ./btrfs.nix {
      deviceName = "/dev/disk/by-id/wwn-0x5002538e00000000";
      swapSize = "16G";
    };
  # Setting the mountpoint with disko and disabling systemd so zfs will mount it
  boot.zfs.extraPools = [ "pool1" ];
  boot.loader.systemd-boot.graceful = true;
  systemd.services.zfs-mount.enable = true;
  # disko.devices = import ./btrfs.nix {
  #     deviceName = "/dev/disk/by-id/wwn-0x5002538e00000000";
  #     swapSize = "16G";
  #   } // {
  #     zpool = {
  #       pool1 = {
  #         type = "zpool";
  #         mountpoint = "/pool1";
  #         datasets = {
  #           pool1 = {
  #             type = "zfs_fs";
  #             options.mountpoint = "/pool1";
  #           };
  #         };
  #       };
  #     };
  #   };
}
