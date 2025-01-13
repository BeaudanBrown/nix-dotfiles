let
  defaultRules = [
    "float, class:(.*)"
  ];
  tilingWindows = builtins.map (x: "tile, " + x) [
    "class:(kitty)"
    "class:(signal)"
    "class:(brave-browser)"
    "class:(Slack)"
    "class:(steam)"
    "class:(Caprine)"
    "title:(Spotify)"
    "class:(teams-for-linux)"
    "class:^(libreoffice.*)$"
  ];
  fullscreenWindows = builtins.map (x: "fullscreen, " + x) [
    "class:(VirtualBox Machine)"
  ];
  nonFullscreenWindows = builtins.map (x: "suppressevent fullscreen maximize, " + x) [
    "class:^(libreoffice.*)$"
  ];
  tallWindows = builtins.map (x: "size 30% 60%, " + x) [
    "class:(nm-openconnect-auth-dialog)"
  ];
  largeWindows = builtins.map (x: "size 60% 60%, " + x) [
    "class:(org.gnome.Nautilus)"
    "class:(org.pulseaudio.pavucontrol)"
  ];
  instantWindows = builtins.map (x: "noanim, " + x) [
    "class:(Rofi)"
  ];
  extraRules = [
    "size 40% 80%, class:(org.pwmt.zathura)"
  ];
in
  defaultRules
  ++ tilingWindows
  ++ fullscreenWindows
  ++ nonFullscreenWindows
  ++ instantWindows
  ++ tallWindows
  ++ largeWindows
  ++ extraRules
