{ pkgs }:

pkgs.writeShellApplication {
  name = "oneplus-audio-readings";

  runtimeInputs = with pkgs; [
    alsa-utils
    coreutils
    gnugrep
    gnused
    gawk
    nodejs
    pipewire
    pulseaudio
    util-linux
  ];

  text = builtins.readFile ./oneplus-audio-readings.sh;
}
