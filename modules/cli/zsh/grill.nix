{ config, lib, ... }:
{
  # systemd owns the shared tmux server, so its panes don't inherit Ghostty's
  # shell integration. Direct Ghostty shells keep Home Manager's normal setup.
  hm.primary.programs.zsh.initContent = lib.mkOrder 1100 ''
    if [[ -o interactive && -n $TMUX && -z $GHOSTTY_RESOURCES_DIR ]] && (( ! $+_ghostty_state )); then
      : ''${GHOSTTY_SHELL_FEATURES=cursor:blink,path,title}
      source ${
        config.home-manager.users.${config.hostSpec.username}.programs.ghostty.package
      }/share/ghostty/shell-integration/zsh/ghostty-integration
    fi
  '';
}
