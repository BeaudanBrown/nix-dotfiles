{ pkgs, ... }:
{
  environment = {
    systemPackages = [ pkgs.weechat ];
  };
}
