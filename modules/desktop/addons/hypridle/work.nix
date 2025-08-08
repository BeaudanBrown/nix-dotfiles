{
  config,
  ...
}:
{
  home-manager.users.${config.hostSpec.username}.services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "pidof hyprlock || hyprlock";
        before_sleep_cmd = "hyprlock";
        after_sleep_cmd = "hyprctl dispatch dpms on";
      };
      listener = [
        {
          timeout = 900;
          on-timeout = "hyprlock";
        }
        {
          timeout = 1800;
          on-timeout = "systemctl suspend";
        }
        # TODO: Add laptop brightness lower
      ];
    };
  };
}
