{ ... }:
{
  services.blueman.enable = true;

  hm.primary = {
    services.blueman-applet.enable = true;

    # Prefer the supervised Home Manager service over Blueman's XDG autostart
    # entry so only one applet races for the tray.
    xdg.configFile."autostart/blueman.desktop".text = ''
      [Desktop Entry]
      Hidden=true
    '';
  };
}
