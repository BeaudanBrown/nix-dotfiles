{ lib, config, ... }: {
  wayland.windowManager.hyprland.settings = {
    bindm = [
      "SUPER,mouse:272,movewindow"
      "SUPER,mouse:273,resizewindow"
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

        "SUPER, s, exec, hyprland_show_app -a slack -c Slack"
        "SUPERSHIFT, s, exec, hyprland_show_app -a slack -c Slack -p"

        "SUPER, c, exec, hyprland_show_app -a signal-desktop"
        "SUPERSHIFT, c, exec, hyprland_show_app -a signal-desktop -p"

        "SUPER, w, exec, hyprland_show_app -a brave -c brave-browser"
        "SUPERSHIFT, w, exec, hyprland_show_app -a brave -c brave-browser -p"

        "SUPER, m, exec, hyprland_show_app -a spotify"
        "SUPERSHIFT, m, exec, hyprland_show_app -a spotify -p"

        #################### Basic Bindings ####################
        "SUPER,q,killactive"
        "SUPERSHIFT,e,exit"

        "SUPER,f,fullscreen,1"
        "SUPERSHIFT,f,fullscreen,0"
        "SUPERSHIFT,space,togglefloating"

        "SUPER,g,togglegroup"
        "SUPER,t,lockactivegroup,toggle"
        "SUPER,apostrophe,changegroupactive,f"
        "SUPERSHIFT,apostrophe,changegroupactive,b"

        "SUPER,u,togglespecialworkspace"
        "SUPERSHIFT,u,movetoworkspacesilent,special"
        "SUPER,TAB,workspace,previous"

        "SUPER,equal, exec, wpctl set-volume -l 1.4 @DEFAULT_AUDIO_SINK@ 5%+"
        "SUPER,minus, exec, wpctl set-volume -l 1.4 @DEFAULT_AUDIO_SINK@ 5%-"
        "SUPERSHIFT,minus, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
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
      # Swap windows
      (lib.mapAttrsToList
        (key: direction:
          "SUPERALT,${key},swapwindow,${direction}"
        )
        directions) ++
      # Move windows
      (lib.mapAttrsToList
        (key: direction:
          "SUPERSHIFT,${key},movewindoworgroup,${direction}"
        )
        directions);
      # # TODO: toggle monitor focus
      # (lib.mapAttrsToList
      #   (key: direction:
      #     "SUPERALT,${key},focusmonitor,${direction}"
      #   )
      #   directions) ++
      # Move workspace to other monitor
  };
}
