{ pkgs }:

pkgs.writeShellApplication {
  name = "oneplus-loop-seed-reboot";

  runtimeInputs = with pkgs; [
    coreutils
    git
  ];

  text = builtins.readFile ./oneplus-loop-seed-reboot.sh;
}
