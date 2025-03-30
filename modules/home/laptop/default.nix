{ lib, ... }:
{
  imports = lib.custom.scanPaths ./.;
  # TODO: Break this out into files
  wayland.windowManager.hyprland.settings.monitor = [
    "eDP-1, 1920x1080@60, 0x0, 1"
  ];
  programs.waybar.settings.mainBar.output = [
    "eDP-1"
  ];
}
