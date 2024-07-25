{ config, pkgs, ... }:
{
  programs.home-manager.enable = true;
  home = {
    username = "beau";
    homeDirectory = "/home/beau";
    stateVersion = "23.05";
    # pointerCursor = {
    #   package = pkgs.quintom-cursor-theme;
    #   name = "Quintom_Ink";
    #   size = 24;
    #   gtk.enable = true;
    # };
  };

  xdg.userDirs = {
    enable = true;
    createDirectories = true;
    documents = "${config.home.homeDirectory}/documents";
    download = "${config.home.homeDirectory}/downloads";
    desktop = null;
    pictures = null;
    music = null;
    publicShare = null;
    templates = null;
    videos = null;
  };

  imports = [
    ./desktops/hyprland
    ./modules/home/bspwm
    ./tmux
    # ./modules/home/sxhkd
  ];

  programs.yazi = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.git = {
    enable = true;
    aliases = {
      lg = "log --all --graph --decorate --oneline";
    };
  };

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
    config = {
      whitelist = {
        prefix = [
          "${config.home.homeDirectory}/shared"
          "${config.home.homeDirectory}/monash"
        ];
      };
    };
  };


  programs.rofi = {
    enable = true;
    terminal = "$TERMINAL";
  };

  programs.oh-my-posh = {
    enable = true;
    enableZshIntegration = true;
    settings = builtins.fromJSON (builtins.unsafeDiscardStringContext (builtins.readFile ./extraConfig/oh-my-posh/oh-my-posh.json));
  };

  programs.kitty = {
    enable = true;
    settings = {
      confirm_os_window_close = 0;
      enable_audio_bell = false;
    };
  };

  programs.wofi = {
    enable = true;
  };

  # programs.wezterm = {
  #   enable = true;
  #   extraConfig = ''
# local wezterm = require 'wezterm'
# local config = {}
# config.enable_tab_bar = false;
# return config
  #   '';
  # };

  programs.feh = {
    enable = true;
    keybindings = {
      prev_img = [
        "h"
        "Left"
      ];
      next_img = [
        "l"
        "Right"
      ];
      zoom_in = "K";
      zoom_out = "J";
    };
  };

  programs.eww = {
    enable = true;
    configDir = ./extraConfig/eww;
  };

  dconf.settings = {
    "org/gnome/shell" = {
      disable-user-extensions = false;

      enabled-extensions = [
        "bluetooth-quick-connect@jarosze.gmail.com"
        "dash-to-panel@jderose9.github.com"
      ];
    };
  };

  home.packages = with pkgs; [
    direnv

    gnomeExtensions.bluetooth-quick-connect
    gnomeExtensions.dash-to-panel
  ];

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

  home.file.".local/share/gpt/default.aichat".source = ./extraConfig/default.aichat;
}
