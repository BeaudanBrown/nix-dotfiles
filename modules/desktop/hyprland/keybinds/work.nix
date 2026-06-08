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
      "SUPER, ${key}, exec, ${appCmd}"
      "SUPERALT, ${key}, exec, ${appCmd} -p"
      "SUPERSHIFT, ${key}, movetoworkspace, name:${workspace}"
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

  screenshot_monitor_region = pkgs.writeShellApplication {
    name = "screenshot_monitor_region";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.grim
      pkgs.hyprland
      pkgs.imagemagick
      pkgs.imv
      pkgs.jq
      pkgs.slurp
      pkgs.wl-clipboard
    ];
    text = ''
      set -euo pipefail

      tmpdir="$(mktemp -d)"
      shot="$tmpdir/screenshot.png"
      viewer_pid=""

      cleanup() {
        if [ -n "$viewer_pid" ]; then
          kill "$viewer_pid" 2>/dev/null || true
        fi
        rm -rf "$tmpdir"
      }
      trap cleanup EXIT

      cursor="$(hyprctl cursorpos | tr -d ' ')"
      mouse_x="''${cursor%,*}"
      mouse_y="''${cursor#*,}"

      monitors="$(hyprctl -j monitors)"
      monitor="$(${pkgs.jq}/bin/jq -c --argjson x "$mouse_x" --argjson y "$mouse_y" '
        first(
          .[]
          | select(
              $x >= .x and $x < (.x + .width) and
              $y >= .y and $y < (.y + .height)
            )
        ) // first(.[] | select(.focused == true))
      ' <<< "$monitors")"

      output="$(${pkgs.jq}/bin/jq -r '.name' <<< "$monitor")"
      monitor_x="$(${pkgs.jq}/bin/jq -r '.x' <<< "$monitor")"
      monitor_y="$(${pkgs.jq}/bin/jq -r '.y' <<< "$monitor")"
      monitor_w="$(${pkgs.jq}/bin/jq -r '.width' <<< "$monitor")"
      monitor_h="$(${pkgs.jq}/bin/jq -r '.height' <<< "$monitor")"

      # Capture immediately, including the cursor, so hover-only UI state is frozen.
      grim -c -o "$output" "$shot"

      # Fullscreen windows generally open on the focused Hyprland monitor.
      hyprctl dispatch focusmonitor "$output" >/dev/null || true
      imv -i posthoc-screenshot -f -s full -b 000000 "$shot" &
      viewer_pid="$!"

      # Give the fullscreen image viewer a moment to map before selecting over it.
      sleep 0.15

      selection="$(slurp)" || exit 0
      pos="''${selection%% *}"
      size="''${selection#* }"
      sel_x="''${pos%,*}"
      sel_y="''${pos#*,}"
      sel_w="''${size%x*}"
      sel_h="''${size#*x}"

      sel_right=$((sel_x + sel_w))
      sel_bottom=$((sel_y + sel_h))
      mon_right=$((monitor_x + monitor_w))
      mon_bottom=$((monitor_y + monitor_h))

      crop_left="$sel_x"
      crop_top="$sel_y"
      crop_right="$sel_right"
      crop_bottom="$sel_bottom"

      if [ "$crop_left" -lt "$monitor_x" ]; then crop_left="$monitor_x"; fi
      if [ "$crop_top" -lt "$monitor_y" ]; then crop_top="$monitor_y"; fi
      if [ "$crop_right" -gt "$mon_right" ]; then crop_right="$mon_right"; fi
      if [ "$crop_bottom" -gt "$mon_bottom" ]; then crop_bottom="$mon_bottom"; fi

      crop_w=$((crop_right - crop_left))
      crop_h=$((crop_bottom - crop_top))
      if [ "$crop_w" -le 0 ] || [ "$crop_h" -le 0 ]; then
        exit 0
      fi

      crop_x=$((crop_left - monitor_x))
      crop_y=$((crop_top - monitor_y))

      magick "$shot" -crop "''${crop_w}x''${crop_h}+''${crop_x}+''${crop_y}" +repage png:- \
        | wl-copy --type image/png
    '';
  };

  baseBinds = [
    # Program launchers (rofi etc.)
    "SUPER, space, exec, rofi -show drun -matching fuzzy"
    "SUPER, p, exec, rofi -show 'Browse ' -modes 'Browse :${rofi_launch_dir}/bin/rofi_launch_dir' -matching fuzzy"
    "SUPER, i, exec, ${pkgs.rofi-rbw-wayland}/bin/rofi-rbw"

    # Screenshot region to clipboard
    ", Print, exec, ${pkgs.grim}/bin/grim -g \"$(${pkgs.slurp}/bin/slurp)\" - | wl-copy"

    # Screenshot the monitor under the mouse, then crop that frozen image to clipboard.
    "SHIFT, Print, exec, ${screenshot_monitor_region}/bin/screenshot_monitor_region"

    # Push-to-dictate
    "SUPER, z, exec, stt-dictate toggle"

    # Push-to-assistant (STT → LLM → TTS + paste)
    "SUPERSHIFT, z, exec, stt-assist toggle"

    # Push-to-thought-capture (STT → structured thought store on grill)
    "SUPERALT, z, exec, thought-capture toggle"

    # Basic binds
    "SUPER,x,exec,hyprlock"
    "SUPERSHIFT,x,exec,systemctl hibernate"
    "SUPER,q,killactive"
    "SUPERSHIFT,e,exit"
    "SUPER,f,fullscreen,1"
    "SUPERSHIFT,f,fullscreen,0"
    "SUPERSHIFT,space,togglefloating"

    # Special workspace
    "SUPER,u,togglespecialworkspace"
    "SUPERSHIFT,u,movetoworkspacesilent,special"

    "SUPER,TAB,workspace,previous"
    "SUPERSHIFT,TAB,workspace,m+1"
    "ALT,TAB,focusCurrentOrLast"

    # Media
    "SUPERSHIFT, equal, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
    "SUPERSHIFT, p, exec, playerctl play-pause"
    "SUPER, period, exec, playerctl next"
    "SUPER, comma, exec, playerctl previous"

    # Monitor switching
    "SUPER, h, focusmonitor, +1"
    "SUPERSHIFT, h, movewindow, mon:+1"
    "SUPERALT, h, moveworkspacetomonitor, e+0 +1"

    # Window focus
    "SUPER, j, layoutmsg, cyclenext"
    "SUPER, k, layoutmsg, cycleprev"
    "SUPER, l, layoutmsg, focusmaster"

    # Window movement
    "SUPERSHIFT, j, layoutmsg, swapnext"
    "SUPERSHIFT, k, layoutmsg, swapprev"
    "SUPERSHIFT, l, layoutmsg, swapwithmaster"
  ]
  ++ map (n: "SUPER,${n},workspace,name:${n}") workspaces
  ++ map (n: "SUPERSHIFT,${n},movetoworkspacesilent,name:${n}") workspaces;
in
{
  hypr.launchers = [
    {
      key = "Return";
      app = "ghostty --title=main-terminal";
      workspace = "ghostty";
      title = "main-terminal";
    }
    {
      key = "s";
      app = "slack";
      workspace = "Slack";
      class = "slack";
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
      title = "Caprine";
    }
    config.hypr.windowsLauncher
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
      app = "ghostty --gtk-single-instance=false --title=nas -e ssh nas";
      workspace = "nas";
      title = "nas";
    }
    {
      key = "a";
      app = "ghostty --gtk-single-instance=false --title=agent -e ssh agent";
      workspace = "agent";
      title = "agent";
    }
    {
      key = "r";
      app = "ghostty --gtk-single-instance=false --title=rozzy -e ssh rozzy";
      workspace = "rozzy";
      title = "rozzy";
    }
    {
      key = "t";
      app = "ghostty --gtk-single-instance=false --title=bottom -e ssh bottom";
      workspace = "bottom";
      title = "bottom";
    }
  ];

  hm.primary.wayland.windowManager.hyprland.settings = {
    bindm = [
      "SUPER,mouse:272,movewindow"
      "SUPER,mouse:273,resizewindow"
    ];

    binde = [
      "SUPER,equal, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
      "SUPER,minus, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"

      "SUPER,b, exec, ${pkgs.brightnessctl}/bin/brightnessctl set +10%"
      "SUPERSHIFT,b, exec, ${pkgs.brightnessctl}/bin/brightnessctl set 10%-"

      "SUPERCTRL, h, resizeactive, -20 0"
      "SUPERCTRL, l, resizeactive, 20 0"
      "SUPERCTRL, k, resizeactive, 0 -20"
      "SUPERCTRL, j, resizeactive, 0 20"
    ];

    # Single place where we produce the Hyprland binds:
    bind = baseBinds ++ lib.concatMap launchProgram config.hypr.launchers;
  };
}
