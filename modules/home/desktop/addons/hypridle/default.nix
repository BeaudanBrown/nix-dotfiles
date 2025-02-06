{
  lib,
  namespace,
  config,
  ...
}:
with lib;
with lib.${namespace}; let
  cfg = config.${namespace}.desktop.addons.hypridle;
in {
  options.${namespace}.desktop.addons.hypridle = {
    enable = mkBoolOpt false "Whether to enable hypridle.";
  };

  config = mkIf cfg.enable {
    services.hypridle = {
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
  };
}
