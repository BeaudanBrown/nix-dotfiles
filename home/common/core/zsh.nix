{ config, ... }:
{
  programs.zsh = {
    enable = true;
    syntaxHighlighting.enable = true;
    history.size = 10000;
    defaultKeymap = "viins";
    dotDir = ".config/zsh";
    plugins = [ ];
    sessionVariables = {
      KEYTIMEOUT = 1;
    };
    initExtra = ''
if [[ ! "$TERM" =~ screen ]] && [[ ! "$TERM" =~ tmux ]]; then
  tmux new -A -s default &> /dev/null
fi
function zle-keymap-select {
  case $KEYMAP in
    vicmd)
      echo -ne '\e[1 q'
      ;;
    main|viins|"")
      echo -ne '\e[5 q'
      ;;
  esac
}

zle -N zle-keymap-select

zle-line-init() {
    zle -K viins
    echo -ne '\e[5 q'
}

zle -N zle-line-init

preexec() {
    echo -ne '\e[5 q'
}
DIRENV_CONFIG="${config.home.homeDirectory}/.config/direnv"
compdef batman=man
    '';
  };
}
