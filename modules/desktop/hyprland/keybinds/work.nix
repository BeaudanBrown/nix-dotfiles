{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Build the hyprland_show_app command and 3 binds for each launcher
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
        "hyprland_show_app -a \"${app}\""
        + (if class != null then " -c ${class}" else "")
        + (if workspace != null then " -w ${workspace}" else "")
        + (if title != null then " -t \"${title}\"" else "");
    in
    [
      ''SUPER, ${key}, exec, ${appCmd}''
      ''SUPERALT, ${key}, exec, ${appCmd} -p''
      ''SUPERSHIFT, ${key}, movetoworkspace, name:${workspace}''
    ];

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
    runtimeInputs = [
      pkgs.fd
      pkgs.coreutils
      pkgs.glib
    ];
    text = ''
      if [ "$#" -gt 0 ]; then
        coproc nautilus "$1" > /dev/null  2>&1
        exit 0
      fi
      cd "$HOME" || exit 1
      ${pkgs.fd}/bin/fd -t d -d 5 --no-ignore --strip-cwd-prefix
    '';
  };

  baseBinds = [
    # Program launchers (rofi etc.)
    "SUPER, space, exec, rofi -show drun -matching fuzzy"
    "SUPER, p, exec, rofi -show 'Browse ' -modes 'Browse :${rofi_launch_dir}/bin/rofi_launch_dir' -matching fuzzy"
    "SUPER, i, exec, ${pkgs.rofi-rbw-wayland}/bin/rofi-rbw"

    # Screenshot region to clipboard
    ", Print, exec, ${pkgs.grim}/bin/grim -g \"$(${pkgs.slurp}/bin/slurp)\" - | wl-copy"

    # Basic binds
    "SUPER,x,exec,hyprlock"
    "SUPER,q,killactive"
    "SUPERSHIFT,e,exit"
    "SUPER,f,fullscreen,1"
    "SUPERSHIFT,f,fullscreen,0"
    "SUPERSHIFT,space,togglefloating"

    # Special workspace
    "SUPER,u,togglespecialworkspace"
    "SUPERSHIFT,u,movetoworkspacesilent,special"

    # Switch back
    "SUPER,TAB,workspace,previous"
    "ALT,TAB,focusCurrentOrLast"

    # Media
    "SUPERSHIFT, equal, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
    "SUPERSHIFT, p, exec, playerctl play-pause"
    "SUPER, period, exec, playerctl next"
    "SUPER, comma, exec, playerctl previous"
  ]
  ++ map (n: "SUPER,${n},workspace,name:${n}") workspaces
  ++ map (n: "SUPERSHIFT,${n},movetoworkspacesilent,name:${n}") workspaces
  ++ lib.mapAttrsToList (k: d: "SUPER,${k},movefocus,${d}") directions
  ++ lib.mapAttrsToList (k: d: "SUPERSHIFT,${k},movewindoworgroup,${d}") directions
  ++ lib.mapAttrsToList (k: d: "SUPERALT,${k},moveworkspacetomonitor,e-0 ${d}") directions;
in
{
  hypr.launchers = [
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
    {
      key = "y";
      app = "kitty --class=nas ssh nas";
      workspace = "nas";
      class = "nas";
    }
  ];

  hm.wayland.windowManager.hyprland.settings = {
    bindm = [
      "SUPER,mouse:272,movewindow"
      "SUPER,mouse:273,resizewindow"
    ];

    binde = [
      "SUPER,equal, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
      "SUPER,minus, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"

      "SUPER,b, exec, light -A 10"
      "SUPERSHIFT,b, exec, light -U 10"

      "SUPERCTRL, h, resizeactive, -20 0"
      "SUPERCTRL, l, resizeactive, 20 0"
      "SUPERCTRL, k, resizeactive, 0 -20"
      "SUPERCTRL, j, resizeactive, 0 20"
    ];

    # Single place where we produce the Hyprland binds:
    bind = baseBinds ++ lib.concatMap launchProgram config.hypr.launchers;
  };
}
