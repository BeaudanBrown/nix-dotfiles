{ config, ... }:
{
  home-manager.users.${config.hostSpec.username}.imports = [
    {
      wayland.windowManager.hyprland.settings.monitor = [
        "eDP-1, 1920x1080@60, 0x0, 1"
      ];
    }
  ];
}
