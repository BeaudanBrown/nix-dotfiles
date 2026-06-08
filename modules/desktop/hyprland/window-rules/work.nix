{ ... }:
let
  matchClass = class: { "match:class" = class; };
  matchTitle = title: { "match:title" = title; };
  rule = effect: match: effect // match;
  rules = effect: matches: builtins.map (rule effect) matches;

  defaultRules = [
    (rule { float = "on"; } (matchClass "(.*)"))
  ];
  onCursorWindows = rules { move = "onscreen cursor"; } [
    ({
      "match:class" = "(zoom)";
      "match:title" = "(menu window)";
    })
  ];
  rightClickWindows = rules { size = "5% 10%"; } [
    ({
      "match:class" = "(zoom)";
      "match:title" = "(menu window)";
    })
  ];
  tilingWindows = rules { tile = "on"; } [
    (matchClass "(com.mitchellh.ghostty)")
    (matchClass "(agent)")
    (matchClass "(nas)")
    (matchClass "(rozzy)")
    (matchClass "(t480)")
    (matchClass "(grill)")
    (matchClass "(bottom)")
    (matchClass "(signal)")
    (matchClass "(brave-browser)")
    (matchClass "(slack)")
    (matchClass "(steam)")
    (matchTitle "(Caprine)")
    (matchClass "(discord)")
    (matchTitle "^(Spotify.*)")
    (matchTitle "^(Immich.*)")
    (matchClass "(teams-for-linux)")
    (matchClass "^(libreoffice.*)$")
    (matchClass "(VirtualBox Manager)")
    (matchClass "(org.qbittorrent.qBittorrent)")
    (matchClass "(net.lutris.Lutris)")
    (matchClass "(@joplin/app-desktop)")
    (matchClass "(Github Desktop)")
    (matchClass "(com.obsproject.Studio)")
    (matchClass "(vlc)")
    (matchClass "(org.freecad.FreeCAD)")
  ];
  fullscreenWindows = rules { fullscreen = "on"; } [
    (matchClass "(VirtualBox Machine)")
    ({
      "match:class" = "(remote-viewer)";
      "match:title" = "^(windows)$";
    })
  ];
  nonFullscreenWindows = rules { suppress_event = "fullscreen maximize"; } [
    (matchClass "^(libreoffice.*)$")
  ];
  tallWindows = rules { size = "30% 60%"; } [
    (matchClass "(nm-openconnect-auth-dialog)")
  ];
  largeWindows = rules { size = "60% 60%"; } [
    (matchClass "(org.gnome.Nautilus)")
    (matchClass "(org.pulseaudio.pavucontrol)")
    (matchTitle "^(Connect to VPN .*)")
    (matchClass "(zoom)")
  ];
  instantWindows = rules { no_anim = "on"; } [
    (matchClass "(Rofi)")
  ];
  extraRules = [
    (rule { size = "40% 80%"; } (matchClass "(org.pwmt.zathura)"))
  ];
  noAnimationRules = [
    (rule { no_anim = "on"; } (matchClass "^(ueberzugpp_.*)$"))
    (rule { no_blur = "on"; } (matchClass "^(ueberzugpp_.*)$"))
    (rule { no_shadow = "on"; } (matchClass "^(ueberzugpp_.*)$"))
    (rule { border_size = 0; } (matchClass "^(ueberzugpp_.*)$"))
  ];

  unnamedRules =
    defaultRules
    ++ tilingWindows
    ++ fullscreenWindows
    ++ nonFullscreenWindows
    ++ instantWindows
    ++ tallWindows
    ++ largeWindows
    ++ extraRules
    ++ noAnimationRules
    ++ onCursorWindows
    ++ rightClickWindows;
  namedRules = builtins.genList (
    i: { name = "windowrule-${toString i}"; } // builtins.elemAt unnamedRules i
  ) (builtins.length unnamedRules);
in
{
  hm.primary.wayland.windowManager.hyprland = {
    enable = true;
    xwayland.enable = true;

    settings.windowrule = namedRules;
  };
}
