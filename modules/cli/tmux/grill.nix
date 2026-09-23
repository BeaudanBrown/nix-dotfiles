{ config, pkgs, ... }:
let
  rawTmux = pkgs.tmux.rawTmux;
  guard = pkgs.writeShellApplication {
    name = "tmux-relay-update-guard";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.systemd
      pkgs.gnugrep
    ];
    text = ''
      socket="''${XDG_RUNTIME_DIR:?}/tmux-$(id -u)/default"
      raw_tmux=${rawTmux}/bin/tmux
      shared_unit=tmux-shared.service
      ${builtins.readFile ./shared-guard.sh}
    '';
  };
  start = pkgs.writeShellApplication {
    name = "tmux-shared-start";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.nix
    ];
    text = ''
      socket="''${XDG_RUNTIME_DIR:?}/tmux-$(id -u)/default"
      if ${rawTmux}/bin/tmux -N -S "$socket" display-message -p '#{pid}' >/dev/null 2>&1; then
        echo 'Refusing to replace an existing tmux server; migration requires explicit maintenance' >&2
        exit 1
      fi
      umask 077
      mkdir -p "$(dirname "$socket")" "$HOME/.local/state/tmux-shared"
      chmod 700 "$(dirname "$socket")" "$HOME/.local/state/tmux-shared"
      # Retain the running generation, including its Home Manager plugins and
      # hook executables, until the next deliberate server start.
      nix-store --add-root "$HOME/.local/state/tmux-shared/runtime" --indirect --realise "$(readlink -f /run/current-system)" >/dev/null
      unset TMUX TMUX_PANE
      export TMUX_TMPDIR="$XDG_RUNTIME_DIR"
      exec ${rawTmux}/bin/tmux -D -S "$socket" -f "$HOME/.config/tmux/tmux.conf"
    '';
  };
in
{
  services.pi-harness.managedSessions.updateGuard = guard;
  systemd.user.services.tmux-shared = {
    description = "Independent shared tmux server (never replaced during rebuild)";
    unitConfig.ConditionUser = config.hostSpec.username;
    restartIfChanged = false;
    stopIfChanged = false;
    # Deliberately no PartOf/BindsTo/Requires relation to the relay.
    path = [ pkgs.tmux ] ++ (import ./tmux-runtime.nix { inherit pkgs; });
    serviceConfig = {
      Type = "simple";
      ExecStart = "${start}/bin/tmux-shared-start";
      Restart = "on-failure";
      RestartSec = 2;
      UMask = "0077";
    };
  };
}
