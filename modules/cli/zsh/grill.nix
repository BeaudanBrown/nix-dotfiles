{ ... }:
{
  hmModules.primary = [
    (
      { config, lib, ... }:
      {
        # Load after the normal integration; systemd-owned panes lack its environment.
        programs.zsh.initContent = lib.mkOrder 1100 ''
          if [[ -o interactive && -n $TMUX && -z $GHOSTTY_RESOURCES_DIR ]] && (( ! $+_ghostty_state )); then
            : ''${GHOSTTY_SHELL_FEATURES=cursor:blink,path,title}
            source ${config.programs.ghostty.package}/share/ghostty/shell-integration/zsh/ghostty-integration
          fi
        '';
      }
    )
  ];
}
