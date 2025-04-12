{ lib, ... }:
{
  imports = lib.custom.importRecursive ./.;

  # TODO: Break this out into files
  wayland.windowManager.hyprland.settings.monitor = [
    "DP-1, 2560x1440@144, 0x0, 1, vrr, 1"
    "DP-2, 2560x1440@144, 2560x0, 1, vrr, 1"
  ];
  programs.waybar.settings.mainBar.output = [
    "DP-1"
    "DP-2"
  ];
}
