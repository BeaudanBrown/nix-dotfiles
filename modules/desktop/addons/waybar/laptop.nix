{ config, ... }:
{
  home-manager.users.${config.hostSpec.username}.imports = [
    {
      programs.waybar.settings.mainBar.output = [
        "eDP-1"
      ];
    }
  ];
}
