{ config, lib, ... }:
let
  leftMonitorWorkspaces =
    [
      "ghostty"
      "Slack"
      "agent"
      "rozzy"
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
  hm.primary.wayland.windowManager.hyprland.settings.workspace =
    leftMonitorWorkspaces
    ++ rightMonitorWorkspaces
    ++ lib.optionals (config.hostSpec.hostName == "grill") [
      "name:streaming,monitor:STREAM,default:true,persistent:true"
    ];
}
