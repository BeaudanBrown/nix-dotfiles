{ lib, config, ... }: {
  wayland.windowManager.hyprland.settings = {
    bindm = [
      "SUPER,mouse:272,movewindow"
      "SUPER,mouse:273,resizewindow"
    ];

    binde = [
      "SUPER,equal, exec, wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+"
      "SUPER,minus, exec, wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%-"

      "SUPER,b, exec, light -A 10"
      "SUPERSHIFT,b, exec, light -U 10"
    ];

    bind =
      let
        workspaces = [
          "0"
          "1"
          "2"
          "3"
          "4"
          "5"
          "6"
          "7"
          "8"
          "9"
        ];
        # Map keys (arrows and hjkl) to hyprland directions (l, r, u, d)
        directions = rec {
          left = "l";
          right = "r";
          up = "u";
          down = "d";
          h = left;
          l = right;
          k = up;
          j = down;
        };
      in
      [
        #################### Program Launch ####################
        "SUPER, space, exec, wofi --show drun"

        "SUPER, Return, exec, hyprland_show_app -a $TERMINAL"
        "SUPERSHIFT, Return, exec, hyprland_show_app -a $TERMINAL -p"

        "SUPER, s, exec, hyprland_show_app -a slack -c Slack -w Slack"
        "SUPERSHIFT, s, exec, hyprland_show_app -a slack -c Slack -w Slack -p"

        "SUPER, c, exec, hyprland_show_app -a signal-desktop -c signal -w Signal"
        "SUPERSHIFT, c, exec, hyprland_show_app -a signal-desktop -c signal -w Signal -p"

        "SUPER, w, exec, hyprland_show_app -a brave -c brave-browser -w Brave"
        "SUPERSHIFT, w, exec, hyprland_show_app -a brave -c brave-browser -w Brave -p"

        "SUPER, m, exec, hyprland_show_app -a spotify -t \"Spotify Premium\" -w Spotify"
        "SUPERSHIFT, m, exec, hyprland_show_app -a spotify -t \"Spotify Premium\" -w Spotify -p"

        "SUPER, n, exec, hyprland_show_app -a caprine -c Caprine -w Caprine"
        "SUPERSHIFT, n, exec, hyprland_show_app -a caprine -c Caprine -w Caprine -p"

        "SUPER, v, exec, hyprland_show_app -a launch_windows -c \"VirtualBox Machine\" -w Windows"
        "SUPERSHIFT, v, exec, hyprland_show_app -a launch_windows -c \"VirtualBox Machine\" -w Windows -p"

        "SUPER, g, exec, hyprland_show_app -a steam -c Steam -w Steam"
        "SUPERSHIFT, g, exec, hyprland_show_app -a steam -c Steam -w Steam -p"


        #################### Basic Bindings ####################
        "SUPER,x,exec,hyprlock"

        "SUPER,q,killactive"
        "SUPERSHIFT,e,exit"

        "SUPER,f,fullscreen,1"
        "SUPERSHIFT,f,fullscreen,0"
        "SUPERSHIFT,space,togglefloating"

        "SUPER,u,togglespecialworkspace"
        "SUPERSHIFT,u,movetoworkspacesilent,special"
        "SUPER,TAB,workspace,previous"

        "ALT,TAB,focusCurrentOrLast"

        "SUPERSHIFT,p, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
      ] ++
      # Change workspace
      (map
        (n:
          "SUPER,${n},workspace,name:${n}"
        )
        workspaces) ++
      # Move window to workspace
      (map
        (n:
          "SUPERSHIFT,${n},movetoworkspacesilent,name:${n}"
        )
        workspaces) ++
      # Move focus
      (lib.mapAttrsToList
        (key: direction:
          "SUPER,${key},movefocus,${direction}"
        )
        directions) ++
      # Move windows
      (lib.mapAttrsToList
        (key: direction:
          "SUPERSHIFT,${key},movewindoworgroup,${direction}"
        )
        directions) ++
      # Move workspace to other monitor
      (lib.mapAttrsToList
        (key: direction:
          "SUPERALT,${key},moveworkspacetomonitor,e-0 ${direction}"
        )
        directions);
      # # Swap windows
      # (lib.mapAttrsToList
      #   (key: direction:
      #     "SUPERALT,${key},swapwindow,${direction}"
      #   )
      #   directions) ++
  };
}
