{ pkgs, ... }:
{
  # Issues with zfs in latest kernel
  boot.kernelPackages = pkgs.linuxPackages_6_17;
}
