{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "tmux_toggle_popup";
  runtimeInputs = [ pkgs.tmux ];
  text = builtins.readFile ./tmux_toggle_popup.sh;
}
