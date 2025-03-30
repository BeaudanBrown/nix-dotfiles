{
  config,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.suites.laptop;
in
{
  options.${namespace}.suites.laptop = with types; {
    enable = mkBoolOpt false "Whether or not to enable laptop configuration.";
  };

  config = mkIf cfg.enable {
    services.openssh.ports = [ 8023 ];
    services.xserver.videoDrivers = [ "displaylink" ];
    dotfiles = {
      home.extraOptions = {
        wayland.windowManager.hyprland.settings.monitor = [
          "eDP-1, 1920x1080@60, 0x0, 1"
        ];
        programs.waybar.settings.mainBar.output = [
          "eDP-1"
        ];
      };
    };
  };
}
