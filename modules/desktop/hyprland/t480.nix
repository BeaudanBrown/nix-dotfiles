{ lib, ... }:
{
  hm.wayland.windowManager.hyprland.settings = {
    monitor = [
      "eDP-1, 1920x1080@60, 0x0, 1"
      ", preferred, auto-up, 1"
    ];
    input.sensitivity = (lib.mkForce 0.2);
    device = [
      {
        name = "synaptics-tm3512-001";
        sensitivity = 0.8;
        accel_profile = "flat";
      }
    ];
  };
}
