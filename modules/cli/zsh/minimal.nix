{
  pkgs,
  config,
  lib,
  ...
}:
{
  programs.zsh.enable = true;
  environment.shells = [ pkgs.zsh ];

  hm.programs.zsh = {
    enable = true;
    syntaxHighlighting.enable = true;
    history.size = 10000;
    defaultKeymap = "viins";
    dotDir = "${config.hostSpec.home}/.config/zsh";
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

          # Fix backspace behavior in vi insert mode
          # Allow backspace to delete past the point where insert mode was entered
          bindkey -M viins '^?' backward-delete-char
          bindkey -M viins '^H' backward-delete-char

          # Ctrl+P: fzf open file or cd into directory (respects .gitignore by default)
          # Press Ctrl+G while in fzf to toggle between respecting/ignoring .gitignore
          # If file selected: open in $EDITOR, if directory selected: cd into it
          fzf-open-file-or-dir() {
            local out
            out=$(fd --hidden --follow --exclude .git 2> /dev/null | \
              fzf --exit-0 \
                --height=40% \
                --layout=reverse \
                --border=none \
                --prompt="GIT> " \
                --header="CTRL-G: toggle gitignore" \
                --bind "ctrl-g:reload(fd --hidden --follow --exclude .git --no-ignore)+change-prompt(ALL> )+change-header(CTRL-G: toggle gitignore)")

            if [ -f "$out" ]; then
              ''${EDITOR:-vim} "$out" < /dev/tty
              zle reset-prompt
            elif [ -d "$out" ]; then
              zle push-line
              BUFFER="builtin cd -- ''${(q)out}"
              zle accept-line
            fi
          }
          zle -N fzf-open-file-or-dir
          bindkey '^P' fzf-open-file-or-dir

          if [[ ! "$TERM" =~ screen ]] && [[ ! "$TERM" =~ tmux ]]; then
            tmux new -A -s default &> /dev/null
          fi

          DIRENV_CONFIG="${
            config.home-manager.users.${config.hostSpec.username}.home.homeDirectory
          }/.config/direnv"
          compdef batman=man
        '';
  };
}
