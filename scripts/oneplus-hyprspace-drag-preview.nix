{
  pkgs,
  oneplus-screenshot,
  oneplus-touch,
}:

pkgs.writeShellApplication {
  name = "oneplus-hyprspace-drag-preview";

  runtimeInputs = [
    pkgs.coreutils
    pkgs.gawk
    pkgs.hyprland
    pkgs.ydotool
    oneplus-screenshot
    oneplus-touch
  ];

  text = builtins.readFile ./oneplus-hyprspace-drag-preview.sh;
}
