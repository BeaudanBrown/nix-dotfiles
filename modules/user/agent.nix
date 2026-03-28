{
  lib,
  ...
}:
{
  hm.all.xdg = {
    userDirs = {
      enable = lib.mkForce false;
    };
  };

  hm.primary.programs.zsh.initExtra = lib.mkAfter ''
    if [[ -n "$TMUX" ]]; then
      current_tmux_session="$(tmux display-message -p '#S' 2>/dev/null || true)"
      pi_harness_path="/home/beau/host/projects/pi-harness"

      if [[ "$current_tmux_session" == "default" ]] && [[ -d "$pi_harness_path" ]]; then
        if ! tmux list-windows -t default -F '#W' | grep -qx 'pi-harness'; then
          tmux new-window -d -t default -n pi-harness -c "$pi_harness_path"
        fi
      fi
    fi
  '';
}
