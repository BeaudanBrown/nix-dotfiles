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
  largeWindows = builtins.map (x: "size 30% 60%, " + x) [
    "class:(nm-openconnect-auth-dialog)"
  ];
in
  defaultRules ++ tilingWindows ++ fullscreenWindows ++ largeWindows
