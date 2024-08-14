let
  defaultRules = [
    "float, class:(.*)"
  ];
  tilingWindows = builtins.map (x: "tile, " + x) [
    "class:(kitty)"
    "class:(signal)"
    "class:(brave-browser)"
    "class:(spotify)"
  ];
in
  defaultRules ++ tilingWindows
