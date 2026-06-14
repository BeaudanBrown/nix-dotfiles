{ pkgs }:

pkgs.writeShellApplication {
  name = "debug-oneplus-mic";

  runtimeInputs = with pkgs; [
    alsa-utils
    coreutils
    fd
    gawk
    gnugrep
    gnused
    sox
  ];

  text = builtins.readFile ./debug-oneplus-mic.sh;
}
