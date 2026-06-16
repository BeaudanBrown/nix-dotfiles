{ pkgs }:

pkgs.writeShellApplication {
  name = "oneplus-touch";

  runtimeInputs = with pkgs; [
    coreutils
    gawk
    ydotool
  ];

  text = builtins.readFile ./oneplus-touch.sh;
}
