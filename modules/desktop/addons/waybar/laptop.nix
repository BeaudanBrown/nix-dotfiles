{
  config,
  ...
}:
{
  home-manager.users.${config.hostSpec.username}.programs.waybar.settings.mainBar.output = [
    "eDP-1"
  ];
}
