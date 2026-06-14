{ pkgs, debug-oneplus-mic }:

pkgs.writeShellApplication {
  name = "oneplus-mic-trial";

  runtimeInputs = with pkgs; [
    alsa-utils
    coreutils
    debug-oneplus-mic
    git
    gnugrep
    gnused
    systemd
  ];

  text = builtins.readFile ./oneplus-mic-trial.sh;
}
