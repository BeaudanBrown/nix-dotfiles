{ ... }:
{
  # Starting activated crashes Waybar 0.15.0 with Gdk Error 22 on this host.
  # Enable inhibition manually after startup until the surface-timing bug is fixed:
  # https://github.com/Alexays/Waybar/issues/5128
  hm.primary.programs.waybar.settings.mainBar.idle_inhibitor.start-activated = false;
  hm.primary.programs.waybar.settings.mainBar.output = [
    "DP-1"
    "DP-2"
  ];
}
