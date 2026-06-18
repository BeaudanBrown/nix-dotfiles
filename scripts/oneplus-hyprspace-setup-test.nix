{ pkgs }:

pkgs.writeShellApplication {
  name = "oneplus-hyprspace-setup-test";

  runtimeInputs = with pkgs; [
    coreutils
    ghostty
    hyprland
    jq
  ];

  text = builtins.readFile ./oneplus-hyprspace-setup-test.sh;
}
