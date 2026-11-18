{ config, pkgs, ... }:
let
  rawTmux = pkgs.tmux.rawTmux;
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
      ${builtins.readFile ./shared-path.sh}
      export TMUX_TMPDIR="$XDG_RUNTIME_DIR"
      exec ${rawTmux}/bin/tmux -D -S "$socket" -f "$HOME/.config/tmux/tmux.conf"
    '';
  };
in
{
  users.users.${config.hostSpec.username}.linger = true;
  systemd.user.services.tmux-shared = {
    description = "Independent shared tmux server (never replaced during rebuild)";
    wantedBy = [ "default.target" ];
    before = [ "pi-matrix-bridge.service" ];
    unitConfig.ConditionUser = config.hostSpec.username;
    restartIfChanged = false;
    stopIfChanged = false;
    # Deliberately no PartOf/BindsTo/Requires relation to the optional bridge.
    path = [ pkgs.tmux ] ++ (import ./tmux-runtime.nix { inherit pkgs; });
    serviceConfig = {
      Type = "simple";
      ExecStart = "${start}/bin/tmux-shared-start";
      ExecStartPost = pkgs.writeShellScript "tmux-shared-ready" ''
        socket="$XDG_RUNTIME_DIR/tmux-$(${pkgs.coreutils}/bin/id -u)/default"
        for ((i = 0; i < 100; i++)); do
          pid=$(${rawTmux}/bin/tmux -N -S "$socket" display-message -p '#{pid}' 2>/dev/null) && [[ $pid == "$MAINPID" ]] && exit 0
          ${pkgs.coreutils}/bin/sleep 0.05
        done
        echo 'Shared tmux did not become ready' >&2
        exit 1
      '';
      Restart = "on-failure";
      RestartSec = 2;
      UMask = "0077";
    };
  };
}
