{ pkgs }:

pkgs.writeShellApplication {
  name = "oneplus-key";

  runtimeInputs = with pkgs; [
    coreutils
    wtype
    ydotool
  ];

  text = builtins.readFile ./oneplus-key.sh;
}
