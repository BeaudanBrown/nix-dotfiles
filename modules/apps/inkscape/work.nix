{ pkgs, ... }:
{
  environment = {
    systemPackages = [ pkgs.inkscape ];
  };
}
