{ pkgs }:

pkgs.writeShellApplication {
  name = "oneplus-screenshot";

  runtimeInputs = with pkgs; [
    coreutils
    grim
    imagemagick
  ];

  text = builtins.readFile ./oneplus-screenshot.sh;
}
