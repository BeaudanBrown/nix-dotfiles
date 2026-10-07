{ ... }:
{
  disko.devices = (
    import ./btrfs.nix {
      deviceName = "/dev/disk/by-id/wwn-0x5002538e4985d990";
      diskName = "grill";
      # Disko creates this size on fresh installs; resize an existing swapfile
      # separately with swap disabled (never rerun disk formatting).
      swapSize = "128G";
    }
  );
}
