{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "hyprland_show_app";
  runtimeInputs = with pkgs; [ jq ];
  text = builtins.readFile ./hyprland_show_app.sh;
}
