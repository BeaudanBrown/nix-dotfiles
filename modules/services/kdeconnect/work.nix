{ ... }:
{
  hm.primary = {
    services.kdeconnect = {
      enable = true;
      indicator = true;
    };

    # KDE Connect is owned by Home Manager's daemon service; suppress the
    # package-provided XDG autostart entry to avoid a startup race.
    xdg.configFile."autostart/org.kde.kdeconnect.daemon.desktop".text = ''
      [Desktop Entry]
      Hidden=true
    '';
  };
}
