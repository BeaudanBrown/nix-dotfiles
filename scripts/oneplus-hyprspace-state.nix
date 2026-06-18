{ pkgs }:

pkgs.writeShellApplication {
  name = "oneplus-hyprspace-state";

  runtimeInputs = with pkgs; [
    coreutils
    hyprland
  ];

  text = builtins.readFile ./oneplus-hyprspace-state.sh;
}
