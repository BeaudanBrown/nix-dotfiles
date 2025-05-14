{ config, ... }:
{
  home-manager.users.${config.hostSpec.username}.imports = [
    {
      programs.waybar.settings.mainBar.output = [
        "DP-1"
        "DP-2"
      ];
    }
  ];
}
