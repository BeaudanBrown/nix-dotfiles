{ ... }:
{
  hm.primary = {
    # Waybar exposes a StatusNotifier tray, so prefer the indicator backend.
    xsession.preferStatusNotifierItems = true;

    services.network-manager-applet.enable = true;

    # The package also ships an XDG autostart entry. Mask it so the supervised
    # Home Manager service is the applet's only startup owner.
    xdg.configFile."autostart/nm-applet.desktop".text = ''
      [Desktop Entry]
      Hidden=true
    '';

    systemd.user.services.network-manager-applet.Service = {
      Restart = "on-failure";
      RestartSec = 2;
    };
  };
}
