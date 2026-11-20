{ config, lib, ... }:
{
  hm.primary.wayland.windowManager.hyprland.settings.monitor = [
    "DP-1, 2560x1440@144, 0x0, 1, vrr, 1"
    "DP-2, 2560x1440@144, 2560x0, 1, vrr, 1"
  ]
  ++ lib.optional config.custom.sunshine.fixedStream "STREAM,1920x1080@60,10000x10000,1";
}
