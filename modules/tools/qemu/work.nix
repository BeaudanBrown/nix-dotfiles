{ pkgs, ... }:
{
  environment = {
    systemPackages = [ pkgs.qemu ];
  };
}
