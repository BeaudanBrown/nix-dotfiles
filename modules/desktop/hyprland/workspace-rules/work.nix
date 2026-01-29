{ ... }:
let
  leftMonitorWorkspaces =
    [
      "kitty"
      "Slack"
    ]
    |> builtins.map (name: "name:" + name + ", monitor:DP-1");
  rightMonitorWorkspaces =
    [
      "Spotify"
      "Brave"
      "Steam"
      "Signal"
      "Caprine"
    ]
    |> builtins.map (name: "name:" + name + ", monitor:DP-2");
in
{
  hm.wayland.windowManager.hyprland.settings.workspace =
    leftMonitorWorkspaces ++ rightMonitorWorkspaces;
}
