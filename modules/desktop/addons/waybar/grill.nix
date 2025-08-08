{
  config,
  ...
}:
{
  home-manager.users.${config.hostSpec.username}.programs.waybar.settings.mainBar.output = [
    "DP-1"
    "DP-2"
  ];
}
