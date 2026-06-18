{ pkgs }:

pkgs.writeShellApplication {
  name = "oneplus-hyprspace-hitboxes";

  runtimeInputs = with pkgs; [
    coreutils
    findutils
    ripgrep
    systemd
  ];

  text = builtins.readFile ./oneplus-hyprspace-hitboxes.sh;
}
