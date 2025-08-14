{ ... }:
{
  services.zfs.autoScrub.enable = true;
  services.zfs.autoSnapshot.enable = true;
  # sudo zfs get -r mountpoint
  disko.devices = import ./btrfs.nix {
    deviceName = "/dev/disk/by-id/nvme-eui.000000000000000100a075254e29ad87";
    swapSize = "16G";
  };
  boot.zfs.extraPools = [ "pool1" ];
  boot.loader.systemd-boot.graceful = true;
  systemd.services.zfs-mount.enable = true;
}
