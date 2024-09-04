{ pkgs, config, ... }:
{
  programs.zsh = {
    enable = true;
    syntaxHighlighting.enable = true;
    history.size = 10000;
    defaultKeymap = "viins";
    dotDir = ".config/zsh";
    plugins = [
      {
        name = "zsh-vi-mode";
        src = pkgs.fetchFromGitHub {
          owner = "jeffreytse";
          repo = "zsh-vi-mode";
          rev = "v0.11.0";
          sha256 = "sha256-xbchXJTFWeABTwq6h4KWLh+EvydDrDzcY9AQVK65RS8=";
        };
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

    initExtraBeforeCompInit = ''
    zmodload zsh/complist
    zstyle ':completion:*' menu select
    bindkey -M menuselect 'h' vi-backward-char
    bindkey -M menuselect 'k' vi-up-line-or-history
    bindkey -M menuselect 'l' vi-forward-char
    bindkey -M menuselect 'j' vi-down-line-or-history
    '';

    initExtra = ''
if [[ ! "$TERM" =~ screen ]] && [[ ! "$TERM" =~ tmux ]]; then
  tmux new -A -s default &> /dev/null
fi

zle -N zle-line-init

preexec() {
    echo -ne '\e[5 q'
}
DIRENV_CONFIG="${config.home.homeDirectory}/.config/direnv"
compdef batman=man
    '';
  };
}
