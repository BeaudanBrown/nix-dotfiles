{ pkgs, lib, ... }:
{
  bindm = [
    "SUPER,mouse:272,movewindow"
    "SUPER,mouse:273,resizewindow"
  ];

  binde = [
    "SUPER,equal, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
    "SUPER,minus, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"

    "SUPER,b, exec, light -A 10"
    "SUPERSHIFT,b, exec, light -U 10"

    "SUPERCTRL, h, resizeactive, -20 0" # Shrink width (move right edge left)
    "SUPERCTRL, l, resizeactive, 20 0" # Grow width (move right edge right)
    "SUPERCTRL, k, resizeactive, 0 -20" # Shrink height (move bottom edge up)
    "SUPERCTRL, j, resizeactive, 0 20" # Grow height (move bottom edge down)
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

      rofi_launch_dir = pkgs.writeShellApplication {
        name = "rofi_launch_dir";
        text = ''
          if [ $# -ne 0 ]; then
            coproc nautilus "$1" > /dev/null  2>&1
            exit 0
          fi
          find "$HOME" -maxdepth 5 -type d -not -path '*/\.*' 2>/dev/null | sed "s|^$HOME/||"
        '';
      };

      launchProgram =
        {
          key,
          app,
          workspace,
          class ? null,
          title ? null,
        }:
        let
          appCmd =
            "hyprland_show_app -a ${app}"
            + (if class != null then " -c ${class}" else "")
            + (if workspace != null then " -w ${workspace}" else "")
            + (if title != null then " -t \"${title}\"" else "");
        in
        [
          ''SUPER, ${key}, exec, ${appCmd}''
          ''SUPERALT, ${key}, exec, ${appCmd} -p''
          ''SUPERSHIFT, ${key}, movetoworkspace, name:${workspace}''
        ];

    in
    lib.concatMap launchProgram [
      {
        key = "Return";
        app = "$TERMINAL";
        workspace = "$TERMINAL";
      }
      {
        key = "s";
        app = "slack";
        workspace = "Slack";
        class = "Slack";
      }
      {
        key = "c";
        app = "signal-desktop";
        workspace = "Signal";
        class = "signal";
      }
      {
        key = "w";
        app = "brave";
        workspace = "Brave";
        class = "brave-browser";
      }
      {
        key = "m";
        app = "spotify";
        workspace = "Spotify";
        class = "spotify";
      }
      {
        key = "n";
        app = "caprine";
        workspace = "Caprine";
        class = "Caprine";
      }
      {
        key = "v";
        app = "launch_windows";
        workspace = "Windows";
        class = "VirtualBox Machine";
      }
      {
        key = "g";
        app = "steam";
        workspace = "Steam";
        class = "Steam";
      }
      {
        key = "d";
        app = "discord";
        workspace = "Discord";
        class = "discord";
      }
    ]
    ++ [
      #################### Program Launch ####################
      "SUPER, space, exec, rofi -show drun"
      "SUPER, p, exec, rofi -show 'Browse ' -modes 'Browse :${rofi_launch_dir}/bin/rofi_launch_dir'"
      "SUPER, i, exec, ${pkgs.rofi-rbw-wayland}/bin/rofi-rbw"

      ", Print, exec, ${pkgs.grim}/bin/grim -g \"$(${pkgs.slurp}/bin/slurp)\" - | wl-copy"

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

      "SUPERSHIFT, equal, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
      "SUPERSHIFT, p, exec, playerctl play-pause"
      "SUPER, period, exec, playerctl next"
      "SUPER, comma, exec, playerctl previous"
    ]
    ++
      # Change workspace
      (map (n: "SUPER,${n},workspace,name:${n}") workspaces)
    ++
      # Move window to workspace
      (map (n: "SUPERSHIFT,${n},movetoworkspacesilent,name:${n}") workspaces)
    ++
      # Move focus
      (lib.mapAttrsToList (key: direction: "SUPER,${key},movefocus,${direction}") directions)
    ++
      # Move windows
      (lib.mapAttrsToList (key: direction: "SUPERSHIFT,${key},movewindoworgroup,${direction}") directions)
    ++
      # Move workspace to other monitor
      (lib.mapAttrsToList (
        key: direction: "SUPERALT,${key},moveworkspacetomonitor,e-0 ${direction}"
      ) directions);
  # # Swap windows
  # (lib.mapAttrsToList
  #   (key: direction:
  #     "SUPERALT,${key},swapwindow,${direction}"
  #   )
  #   directions) ++
}
