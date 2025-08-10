{ ... }:
{
  services.zfs.autoScrub.enable = true;
  # sudo zfs get -r mountpoint
  disko.devices = import ./btrfs.nix {
    deviceName = "/dev/disk/by-id/wwn-0x5002538e90b1957f";
    swapSize = "16G";
  };
  boot.zfs.extraPools = [ "pool1" ];
  boot.loader.systemd-boot.graceful = true;
  systemd.services.zfs-mount.enable = true;
}
