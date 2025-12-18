{ lib, ... }:
{
  hm.wayland.windowManager.hyprland.settings = {
    monitor = [
      "eDP-1, 1920x1080@60, 0x0, 1"
      ", preferred, auto-up, 1"
    ];
    input = {
      sensitivity = (lib.mkForce 0.2);
      touchpad = {
        scroll_factor = (lib.mkForce 1);
      };
    };
    device = [
      {
        name = "synps/2-synaptics-touchpad";
        sensitivity = 1.6;
        accel_profile = "flat";
      }
    ];
  };
}
