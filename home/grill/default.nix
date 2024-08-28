{ config, configLib, pkgs, ... }:
let
  progress-bar = [
    "▏   "
    "▎   "
    "▍   "
    "▌   "
    "▋   "
    "▊   "
    "▉   "
    "█   "
    "█▏  "
    "█▎  "
    "█▍  "
    "█▌  "
    "█▋  "
    "█▊  "
    "█▉  "
    "██  "
    "██▏ "
    "██▎ "
    "██▍ "
    "██▌ "
    "██▋ "
    "██▊ "
    "██▉ "
    "███ "
    "███▏"
    "███▎"
    "███▍"
    "███▌"
    "███▋"
    "███▊"
    "███▉"
    "████"
  ];
in
{
  imports = [
   ] ++ (map configLib.relativeToRoot [
    "home/common/core"
  ]);

  programs.zathura = {
    enable = true;
    mappings = {
      "K" = "zoom out";
      "J" = "zoom in";
    };
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
          "${config.home.homeDirectory}/documents"
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
    settings = builtins.fromJSON (
      builtins.unsafeDiscardStringContext (
        builtins.readFile
        (configLib.relativeToRoot "./extraConfig/oh-my-posh/oh-my-posh.json")
        )
        );
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

  programs.waybar = {
    enable = true;
    style = ''
      * {
        font-family: JetBrainsMono Nerd Font Mono;
      }
    '';
    settings = {
      mainBar = {
        layer = "top";
        position = "bottom";
        height = 30;
        output = [
          "DP-1"
          "DP-2"
        ];
        modules-left = [ "battery" "backlight" "wireplumber" ];
        modules-center = [ "hyprland/workspaces" ];
        modules-right = [ "tray" "memory" "clock" ];
        backlight = {
          device = "intel_backlight";
          format = "🔆 {icon} {percent:3}%";
          format-icons = progress-bar;
        };
        clock = {
          interval = 60;
          tooltip = true;
          format = "{:%I:%M%p}";
          tooltip-format = "{:%a %d/%m/%Y}";
        };
        memory = {
          interval = 10;
          format = "RAM: {used:0.1f}G/{total:0.1f}G";
        };
        wireplumber = {
          format = "🔊 {icon} {volume:3}%";
          format-muted = "🔇";
          # on-click = "helvum";
          format-icons = progress-bar;
        };
        battery = {
          states = {
            # good = 95;
            warning = 30;
            critical = 15;
          };
          format = "🔋 {icon} {capacity:3}%";
          format-charging = "⚡ {icon} {capacity:3}%";
          format-plugged = "⚡ {icon} {capacity:3}%";
          # format-good = ""; # An empty format will hide the module
          # format-full = "";
          format-icons = progress-bar;
        };
      };
    };
  };

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

  home.file.".local/share/gpt/default.aichat".source = (configLib.relativeToRoot "./extraConfig/default.aichat");
}

