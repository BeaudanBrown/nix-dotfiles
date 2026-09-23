{ pkgs }:
let
  activate = pkgs.writeShellScript "nixos-activate-generation" ''
    set -euo pipefail
    ${pkgs.nix}/bin/nix-env --profile /nix/var/nix/profiles/system --set "$1"
    exec "$1/bin/switch-to-configuration" switch
  '';
in
pkgs.writeShellApplication {
  name = "nixos-activate-detached";
  runtimeInputs = [
    pkgs.coreutils
    pkgs.systemd
    pkgs.util-linux
  ];
  text = ''
    if [[ $# != 1 || "$1" != /nix/store/*-nixos-system-* || ! -x "$1/bin/switch-to-configuration" ]]; then
      echo 'Usage: nixos-activate-detached /nix/store/...-nixos-system-HOST-VERSION' >&2
      exit 2
    fi
    unit="nixos-activate-$(date +%s)-$$"
    echo "Activation journal: journalctl -fu $unit.service"
    # Do not use --pipe/--pty: the job must not inherit the invoking terminal.
    # systemd owns it even if sudo, the client, SSH or tmux disappears.
    sudo systemd-run --unit="$unit" --description='Terminal-independent NixOS activation' \
      --property=Type=exec --property=StandardOutput=journal --property=StandardError=journal \
      --wait -- ${pkgs.util-linux}/bin/flock /run/nixos-detached-activation.lock \
      ${activate} "$1"
  '';
}
