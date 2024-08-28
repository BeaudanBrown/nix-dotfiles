let
  leftMonitorWorkspaces = builtins.map (name: "name:" + name + ", monitor:DP-1") [
    "kitty"
    "Slack"
  ];
  rightMonitorWorkspaces = builtins.map (name: "name:" + name + ", monitor:DP-2") [
    "Spotify"
    "Brave"
    "Steam"
    "Signal"
  ];
in
  leftMonitorWorkspaces ++ rightMonitorWorkspaces

