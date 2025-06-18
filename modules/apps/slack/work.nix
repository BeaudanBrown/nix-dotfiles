{ pkgs, ... }:
{
  environment = {
    systemPackages = [ pkgs.slack ];
  };
}
