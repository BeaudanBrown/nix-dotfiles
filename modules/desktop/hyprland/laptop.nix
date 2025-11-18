{ ... }:
{
  hm.wayland.windowManager.hyprland.settings = {
    monitor = [
      "eDP-1, 1920x1080@60, 0x0, 1"
      ", preferred, auto-up, 1"
    ];
    device = [
      {
        name = "2-synaptics-touchpad";
        sensitivity = 0.8;
      }
      {
        name = "syna3091:00-06cb:82f5-touchpad";
        sensitivity = 0.8;
      }
    ];
  };
}
