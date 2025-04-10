{ pkgs, ... }:
{
  environment = {
    systemPackages = [ pkgs.teams-for-linux ];
  };
}
