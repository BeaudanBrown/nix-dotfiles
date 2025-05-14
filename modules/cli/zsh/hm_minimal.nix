{
  config,
  lib,
  pkgs,
  ...
}:
{
  programs.zsh = {
    enable = true;
    syntaxHighlighting.enable = true;
    history.size = 10000;
    defaultKeymap = "viins";
    dotDir = ".config/zsh";
    plugins = [
      {
        name = "fzf-git-sh";
        src = pkgs.fzf-git-sh;
        file = "share/fzf-git-sh/fzf-git.zsh";
      }
    ];
    sessionVariables = {
      KEYTIMEOUT = 1;
    };

    prezto = {
      enable = false;
      caseSensitive = false;
      extraConfig = ''
        zstyle ':prezto:module:utility:ls' dirs-first 'no'
      '';
    };

    initContent =
      lib.mkOrder 550 # bash
        ''
          zmodload zsh/complist
          zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
          zstyle ':completion:*' menu select
          bindkey -M menuselect 'h' vi-backward-char
          bindkey -M menuselect 'k' vi-up-line-or-history
          bindkey -M menuselect 'l' vi-forward-char
          bindkey -M menuselect 'j' vi-down-line-or-history

          if [[ ! "$TERM" =~ screen ]] && [[ ! "$TERM" =~ tmux ]]; then
            tmux new -A -s default &> /dev/null
          fi

          DIRENV_CONFIG="${config.home.homeDirectory}/.config/direnv"
          compdef batman=man
        '';
  };
}
