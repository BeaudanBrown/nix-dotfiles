{ ... }:
let
  defaultRules = [
    "float, class:(.*)"
  ];
  onCursorWindows =
    [
      "class:(zoom), title:(menu window)"
    ]
    |> builtins.map (x: "move onscreen cursor, " + x);
  rightClickWindows =
    [
      "class:(zoom), title:(menu window)"
    ]
    |> builtins.map (x: "size 5% 10%, " + x);
  tilingWindows =
    [
      "class:(kitty)"
      "class:(agent)"
      "class:(nas)"
      "class:(laptop)"
      "class:(grill)"
      "class:(bottom)"
      "class:(signal)"
      "class:(brave-browser)"
      "class:(Slack)"
      "class:(steam)"
      "class:(Caprine)"
      "class:(discord)"
      "title:^(Spotify.*)"
      "title:^(Immich.*)"
      "class:(teams-for-linux)"
      "class:^(libreoffice.*)$"
      "class:(VirtualBox Manager)"
      "class:(org.qbittorrent.qBittorrent)"
      "class:(net.lutris.Lutris)"
      "class:(@joplin/app-desktop)"
      "class:(Github Desktop)"
      "class:(com.obsproject.Studio)"
      "class:(vlc)"
      "class:(org.freecad.FreeCAD)"
    ]
    |> builtins.map (x: "tile, " + x);
  fullscreenWindows =
    [
      "class:(VirtualBox Machine)"
    ]
    |> builtins.map (x: "fullscreen, " + x);
  nonFullscreenWindows =
    [
      "class:^(libreoffice.*)$"
    ]
    |> builtins.map (x: "suppressevent fullscreen maximize, " + x);
  tallWindows =
    [
      "class:(nm-openconnect-auth-dialog)"
    ]
    |> builtins.map (x: "size 30% 60%, " + x);
  largeWindows =
    [
      "class:(org.gnome.Nautilus)"
      "class:(org.pulseaudio.pavucontrol)"
      "title:^(Connect to VPN .*)"
      "class:(zoom)"
    ]
    |> builtins.map (x: "size 60% 60%, " + x);
  instantWindows =
    [
      "class:(Rofi)"
    ]
    |> builtins.map (x: "noanim, " + x);
  extraRules = [
    "size 40% 80%, class:(org.pwmt.zathura)"
  ];
  noAnimationRules = [
    "noanim, class:^(ueberzugpp_.*)$"
    "noblur, class:^(ueberzugpp_.*)$"
    "noshadow, class:^(ueberzugpp_.*)$"
    "noborder, class:^(ueberzugpp_.*)$"
  ];
in
{
  hm.primary.wayland.windowManager.hyprland = {
    enable = true;
    xwayland.enable = true;

    settings.windowrulev2 =
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
  };
}
