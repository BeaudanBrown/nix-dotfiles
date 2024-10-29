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
  ];
  fullscreenWindows = builtins.map (x: "fullscreen, " + x) [
    "class:(VirtualBox Machine)"
  ];
  tallWindows = builtins.map (x: "size 30% 60%, " + x) [
    "class:(nm-openconnect-auth-dialog)"
  ];
  largeWindows = builtins.map (x: "size 60% 60%, " + x) [
    "class:(org.gnome.Nautilus)"
  ];
  instantWindows = builtins.map (x: "noanim, " + x) [
    "class:(Rofi)"
  ];
in
  defaultRules ++ tilingWindows ++ fullscreenWindows ++ instantWindows ++ tallWindows ++ largeWindows
