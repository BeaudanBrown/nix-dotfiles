{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.suites.grill;
in
{
  options.${namespace}.suites.grill = with types; {
    enable = mkBoolOpt false "Whether or not to enable grill configuration.";
  };

  config = mkIf cfg.enable {
    services.openssh.ports = [ 8022 ];
    programs.steam.enable = true;

    dotfiles = {
      home.extraOptions = {
        wayland.windowManager.hyprland.settings.monitor = [
          "DP-1, 2560x1440@144, 0x0, 1, vrr, 1"
          "DP-2, 2560x1440@144, 2560x0, 1, vrr, 1"
        ];
        programs.waybar.settings.mainBar.output = [
          "DP-1"
          "DP-2"
        ];
      };
    };
  };
}
