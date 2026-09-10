{
  config,
  pkgs,
  ...
}:
let
  primaryUser = config.hostSpec.username;
  oneplusHyprctl = pkgs.writeShellScriptBin "oneplus-hyprctl" ''
    set -eu

    uid="$(${pkgs.coreutils}/bin/id -u ${primaryUser})"
    runtime_dir="/run/user/$uid"

    if [ "$(${pkgs.coreutils}/bin/id -u)" = "$uid" ]; then
      exec env \
        XDG_RUNTIME_DIR="$runtime_dir" \
        ${config.programs.hyprland.package}/bin/hyprctl --instance 0 "$@"
    fi

    exec ${pkgs.util-linux}/bin/runuser -u ${primaryUser} -- env \
      XDG_RUNTIME_DIR="$runtime_dir" \
      ${config.programs.hyprland.package}/bin/hyprctl --instance 0 "$@"
  '';
  oneplusSpawn = pkgs.writeShellScriptBin "oneplus-spawn" ''
    set -eu

    if [ "$#" -eq 0 ]; then
      echo "Usage: oneplus-spawn COMMAND [ARGS...]" >&2
      exit 64
    fi

    active="$(${oneplusHyprctl}/bin/oneplus-hyprctl -j activeworkspace)"
    current_id="$(printf '%s\n' "$active" | ${pkgs.jq}/bin/jq -r '.id')"
    monitor_id="$(printf '%s\n' "$active" | ${pkgs.jq}/bin/jq -r '.monitorID')"

    base=10
    if [ "$current_id" -lt "$base" ]; then
      target="$base"
    else
      target=$((current_id + 1))
    fi

    used="$(${oneplusHyprctl}/bin/oneplus-hyprctl -j workspaces \
      | ${pkgs.jq}/bin/jq -r --argjson monitor "$monitor_id" '.[] | select(.monitorID == $monitor and .id >= 1) | .id' \
      | ${pkgs.coreutils}/bin/sort -n)"
    while printf '%s\n' "$used" | ${pkgs.gnugrep}/bin/grep -qx "$target"; do
      target=$((target + 1))
    done

    ${oneplusHyprctl}/bin/oneplus-hyprctl dispatch workspace "$target" >/dev/null
    exec ${oneplusHyprctl}/bin/oneplus-hyprctl dispatch exec "$*"
  '';
  oneplusLauncher = pkgs.writeShellScriptBin "oneplus-launcher" ''
    set -eu

    exec ${pkgs.fuzzel}/bin/fuzzel --show drun "$@"
  '';
  oneplusRestartSqueekboard = pkgs.writeShellScriptBin "oneplus-restart-squeekboard" ''
    set -eu

    ${pkgs.procps}/bin/pkill -x squeekboard || true
    ${pkgs.coreutils}/bin/sleep 0.2
    exec ${oneplusHyprctl}/bin/oneplus-hyprctl dispatch exec squeekboard
  '';
  oneplusFeedbackdThemeJson = ''
    {
      "name" : "$device",
      "parent-name" : "default",
      "profiles" : [
        {
          "name" : "quiet",
          "feedbacks" : [
            {
              "event-name" : "button-pressed",
              "type"       : "VibraRumble",
              "magnitude"  : 1.0,
              "duration"   : 15
            },
            {
              "event-name" : "key-pressed",
              "type"       : "VibraRumble",
              "magnitude"  : 1.0,
              "duration"   : 15
            }
          ]
        }
      ]
    }
  '';
  oneplusFeedbackd = pkgs.feedbackd.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      substituteInPlace src/fbd-dev-vibra.c \
        --replace-fail 'gain.value = 0xC000; /* [0, 0xFFFF]) */' 'gain.value = 0xFFFF; /* [0, 0xFFFF]) */' \
        --replace-fail 'g_debug("Setting master gain to 75%%");' 'g_debug("Setting master gain to 100%%");'
    '';
    postInstall = (old.postInstall or "") + ''
      install -Dm444 ${pkgs.writeText "oneplus-fajita-feedbackd-theme.json" oneplusFeedbackdThemeJson} \
        "$out/share/feedbackd/themes/oneplus,fajita.json"
    '';
  });
  oneplusBrave = pkgs.writeShellScriptBin "oneplus-brave" ''
    set -eu

    exec ${pkgs.brave}/bin/brave \
      --touch-events=enabled \
      --force-device-scale-factor=0.85 \
      --user-agent="Mozilla/5.0 (Linux; Android 14; OnePlus 6T) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Mobile Safari/537.36" \
      "$@"
  '';
  oneplusClipboard = pkgs.writeShellScriptBin "oneplus-clipboard" ''
    set -eu

    uid="$(${pkgs.coreutils}/bin/id -u ${primaryUser})"
    if [ "$(${pkgs.coreutils}/bin/id -u)" != "$uid" ]; then
      exec ${pkgs.util-linux}/bin/runuser -u ${primaryUser} -- "$0" "$@"
    fi

    runtime_dir="/run/user/$uid"
    wayland_socket="$(${pkgs.findutils}/bin/find "$runtime_dir" -maxdepth 1 -type s -name 'wayland-*' -print -quit 2>/dev/null)"
    if [ -z "$wayland_socket" ]; then
      echo "No Wayland socket found" >&2
      exit 1
    fi

    export XDG_RUNTIME_DIR="$runtime_dir"
    export WAYLAND_DISPLAY="$(${pkgs.coreutils}/bin/basename "$wayland_socket")"

    case "''${1:-copy}" in
      copy)
        exec ${pkgs.wl-clipboard}/bin/wl-copy
        ;;
      paste)
        exec ${pkgs.wl-clipboard}/bin/wl-paste
        ;;
      *)
        echo "Usage: oneplus-clipboard [copy|paste]" >&2
        exit 64
        ;;
    esac
  '';
  oneplusKeyboard = pkgs.writeShellScriptBin "oneplus-keyboard" ''
    set -eu

    uid="$(${pkgs.coreutils}/bin/id -u ${primaryUser})"
    if [ "$(${pkgs.coreutils}/bin/id -u)" != "$uid" ]; then
      exec ${pkgs.util-linux}/bin/runuser -u ${primaryUser} -- "$0" "$@"
    fi

    runtime_dir="/run/user/$uid"
    export XDG_RUNTIME_DIR="$runtime_dir"
    export DBUS_SESSION_BUS_ADDRESS="unix:path=$runtime_dir/bus"

    mode="''${1:-toggle}"
    case "$mode" in
      show)
        visible=true
        ;;
      hide)
        visible=false
        ;;
      toggle)
        current="$(${pkgs.glib}/bin/gdbus call --session \
          --dest sm.puri.OSK0 \
          --object-path /sm/puri/OSK0 \
          --method org.freedesktop.DBus.Properties.Get \
          sm.puri.OSK0 Visible 2>/dev/null || true)"
        if printf '%s\n' "$current" | ${pkgs.gnugrep}/bin/grep -q true; then
          visible=false
        else
          visible=true
        fi
        ;;
      *)
        echo "Usage: oneplus-keyboard [show|hide|toggle]" >&2
        exit 64
        ;;
    esac

    exec ${pkgs.glib}/bin/gdbus call --session \
      --dest sm.puri.OSK0 \
      --object-path /sm/puri/OSK0 \
      --method sm.puri.OSK0.SetVisible "$visible"
  '';
  oneplusOverview = pkgs.writeShellScriptBin "oneplus-overview" ''
    set -eu

    action="''${1:-toggle}"
    case "$action" in
      open|close|toggle) ;;
      *)
        echo "Usage: oneplus-overview [open|close|toggle]" >&2
        exit 64
        ;;
    esac

    ${oneplusKeyboard}/bin/oneplus-keyboard hide >/dev/null 2>&1 || true
    exec ${oneplusHyprctl}/bin/oneplus-hyprctl dispatch "overview:$action"
  '';
  oneplusWorkspaceNav = pkgs.writeShellScriptBin "oneplus-workspace-nav" ''
    set -eu

    direction="''${1:-}"
    case "$direction" in
      next|prev) ;;
      *)
        echo "Usage: oneplus-workspace-nav next|prev" >&2
        exit 64
        ;;
    esac

    active="$(${oneplusHyprctl}/bin/oneplus-hyprctl -j activeworkspace)"
    current_id="$(printf '%s\n' "$active" | ${pkgs.jq}/bin/jq -r '.id')"
    monitor_id="$(printf '%s\n' "$active" | ${pkgs.jq}/bin/jq -r '.monitorID')"

    workspaces="$(${oneplusHyprctl}/bin/oneplus-hyprctl -j workspaces \
      | ${pkgs.jq}/bin/jq -r --argjson monitor "$monitor_id" '.[] | select(.monitorID == $monitor and .id >= 1) | .id' \
      | ${pkgs.coreutils}/bin/sort -n)"

    [ -n "$workspaces" ] || exit 0

    target=""
    if [ "$direction" = next ]; then
      target="$(printf '%s\n' "$workspaces" | ${pkgs.gawk}/bin/awk -v cur="$current_id" '$1 > cur { print $1; exit }')"
      if [ -z "$target" ]; then
        target="$(printf '%s\n' "$workspaces" | ${pkgs.coreutils}/bin/head -n1)"
      fi
    else
      target="$(printf '%s\n' "$workspaces" | ${pkgs.gawk}/bin/awk -v cur="$current_id" '$1 < cur { last=$1 } END { print last }')"
      if [ -z "$target" ]; then
        target="$(printf '%s\n' "$workspaces" | ${pkgs.coreutils}/bin/tail -n1)"
      fi
    fi

    [ -n "$target" ] || exit 0
    exec ${oneplusHyprctl}/bin/oneplus-hyprctl dispatch workspace "$target"
  '';
  oneplusTerminalScroll = pkgs.writeShellScriptBin "oneplus-terminal-scroll" ''
    set -eu

    direction="''${1:-}"
    case "$direction" in
      up)
        tmux_scroll="scroll-up"
        fallback_key="Page_Up"
        ;;
      down)
        tmux_scroll="scroll-down"
        fallback_key="Page_Down"
        ;;
      *)
        echo "Usage: oneplus-terminal-scroll up|down" >&2
        exit 64
        ;;
    esac

    focused="$(${oneplusHyprctl}/bin/oneplus-hyprctl -j activewindow 2>/dev/null || true)"
    if ! printf '%s\n' "$focused" | ${pkgs.gnugrep}/bin/grep -Eiq '"(class|initialClass)"[[:space:]]*:[[:space:]]*"(com\.mitchellh\.ghostty|ghostty)"|"title"[[:space:]]*:[[:space:]]*"[^"]*ghostty'; then
      exit 0
    fi

    if ${pkgs.tmux}/bin/tmux list-clients >/dev/null 2>&1; then
      target="$(${pkgs.tmux}/bin/tmux list-clients -F '#{client_activity} #{client_session}:#{client_window}.#{client_pane}' \
        | ${pkgs.coreutils}/bin/sort -nr \
        | ${pkgs.coreutils}/bin/head -n 1 \
        | ${pkgs.coreutils}/bin/cut -d ' ' -f 2-)"
      if [ -n "$target" ]; then
        exec ${pkgs.tmux}/bin/tmux if-shell -t "$target" -F '#{pane_in_mode}' \
          "send-keys -t '$target' -X -N 6 $tmux_scroll" \
          "copy-mode -e -t '$target'; send-keys -t '$target' -X -N 6 $tmux_scroll"
      fi
    fi

    exec ${pkgs.wtype}/bin/wtype -k "$fallback_key"
  '';
  sttDictate =
    (import ../../../../modules/scripts/stt-dictate/work.nix { inherit pkgs; })
    .environment.systemPackages
    |> builtins.head;
  oneplusSttDictate = pkgs.writeShellScriptBin "oneplus-stt-dictate" ''
    set -eu

    uid="$(${pkgs.coreutils}/bin/id -u ${primaryUser})"
    if [ "$(${pkgs.coreutils}/bin/id -u)" != "$uid" ]; then
      exec ${pkgs.util-linux}/bin/runuser -u ${primaryUser} -- "$0" "$@"
    fi

    runtime_dir="/run/user/$uid"
    wayland_socket="$(${pkgs.findutils}/bin/find "$runtime_dir" -maxdepth 1 -type s -name 'wayland-*' -print -quit 2>/dev/null)"
    if [ -z "$wayland_socket" ]; then
      echo "No Wayland socket found" >&2
      exit 1
    fi

    export XDG_RUNTIME_DIR="$runtime_dir"
    export WAYLAND_DISPLAY="$(${pkgs.coreutils}/bin/basename "$wayland_socket")"
    export DBUS_SESSION_BUS_ADDRESS="unix:path=$runtime_dir/bus"

    exec ${sttDictate}/bin/stt-dictate toggle
  '';
  oneplusScreenRecord = pkgs.writeShellScriptBin "oneplus-screen-record" ''
    set -eu

    uid="$(${pkgs.coreutils}/bin/id -u ${primaryUser})"
    if [ "$(${pkgs.coreutils}/bin/id -u)" != "$uid" ]; then
      exec ${pkgs.util-linux}/bin/runuser -u ${primaryUser} -- "$0" "$@"
    fi

    runtime_dir="/run/user/$uid"
    wayland_socket="$(${pkgs.findutils}/bin/find "$runtime_dir" -maxdepth 1 -type s -name 'wayland-*' -print -quit 2>/dev/null)"
    if [ -z "$wayland_socket" ]; then
      echo "No Wayland socket found" >&2
      exit 1
    fi

    export XDG_RUNTIME_DIR="$runtime_dir"
    export WAYLAND_DISPLAY="$(${pkgs.coreutils}/bin/basename "$wayland_socket")"
    export DBUS_SESSION_BUS_ADDRESS="unix:path=$runtime_dir/bus"

    state_dir="$runtime_dir/oneplus-screen-record"
    pidfile="$state_dir/pid"
    outfile_file="$state_dir/outfile"
    logfile="$state_dir/log"
    mkdir -p "$state_dir" "$HOME/Videos/oneplus-recordings"

    cmd="''${1:-status}"
    shift || true

    case "$cmd" in
      start)
        if [ -s "$pidfile" ] && ${pkgs.procps}/bin/kill -0 "$(${pkgs.coreutils}/bin/cat "$pidfile")" 2>/dev/null; then
          echo "Already recording: $(${pkgs.coreutils}/bin/cat "$outfile_file")"
          exit 0
        fi

        outfile="''${1:-$HOME/Videos/oneplus-recordings/oneplus-$(${pkgs.coreutils}/bin/date +%Y%m%d-%H%M%S).mp4}"
        shift || true
        ${pkgs.wf-recorder}/bin/wf-recorder \
          --output DSI-1 \
          --framerate 30 \
          --no-damage \
          --overwrite \
          -f "$outfile" \
          "$@" >"$logfile" 2>&1 &
        pid="$!"
        printf '%s\n' "$pid" >"$pidfile"
        printf '%s\n' "$outfile" >"$outfile_file"
        echo "Recording started: $outfile"
        ;;
      stop)
        if [ ! -s "$pidfile" ]; then
          echo "Not recording"
          exit 1
        fi

        pid="$(${pkgs.coreutils}/bin/cat "$pidfile")"
        outfile="$(${pkgs.coreutils}/bin/cat "$outfile_file" 2>/dev/null || true)"
        if ${pkgs.procps}/bin/kill -0 "$pid" 2>/dev/null; then
          ${pkgs.procps}/bin/kill -INT "$pid"
          for _ in $(${pkgs.coreutils}/bin/seq 1 50); do
            ${pkgs.procps}/bin/kill -0 "$pid" 2>/dev/null || break
            ${pkgs.coreutils}/bin/sleep 0.1
          done
        fi
        ${pkgs.coreutils}/bin/rm -f "$pidfile" "$outfile_file"
        echo "Recording stopped: $outfile"
        ;;
      status)
        if [ -s "$pidfile" ] && ${pkgs.procps}/bin/kill -0 "$(${pkgs.coreutils}/bin/cat "$pidfile")" 2>/dev/null; then
          echo "Recording: $(${pkgs.coreutils}/bin/cat "$outfile_file")"
        else
          echo "Not recording"
        fi
        ;;
      log)
        exec ${pkgs.coreutils}/bin/tail -n 80 "$logfile"
        ;;
      *)
        echo "Usage: oneplus-screen-record start [OUTFILE] [WF_RECORDER_ARGS...] | stop | status | log" >&2
        exit 64
        ;;
    esac
  '';
  hyprlandGestures = pkgs.writeShellScript "oneplus-hyprland-gestures" ''
    exec ${pkgs.lisgd}/bin/lisgd \
      -v \
      -d /dev/input/by-path/platform-a90000.i2c-event \
      -w 1080 \
      -h 2340 \
      -m 1200 \
      -t 60 \
      -r 35 \
      -s 2 \
      -g '1,DU,B,*,R,${oneplusSpawn}/bin/oneplus-spawn ${oneplusLauncher}/bin/oneplus-launcher' \
      -g '1,DU,C,*,R,${oneplusTerminalScroll}/bin/oneplus-terminal-scroll down' \
      -g '1,UD,C,*,R,${oneplusTerminalScroll}/bin/oneplus-terminal-scroll up' \
      -g '1,LR,L,*,R,${oneplusWorkspaceNav}/bin/oneplus-workspace-nav prev' \
      -g '1,RL,R,*,R,${oneplusWorkspaceNav}/bin/oneplus-workspace-nav next' \
      -g '2,DU,*,*,R,${oneplusOverview}/bin/oneplus-overview toggle' \
      -g '2,UD,*,*,R,${oneplusKeyboard}/bin/oneplus-keyboard toggle'
  '';
in
{
  hardware.graphics.enable = true;

  programs.feedbackd = {
    enable = true;
    package = oneplusFeedbackd;
  };
  users.users.${primaryUser}.extraGroups = [ "feedbackd" ];

  services.udev.extraRules = ''
    SUBSYSTEM=="input", KERNEL=="event*", ENV{ID_INPUT}=="1", SUBSYSTEMS=="input", ATTRS{name}=="spmi_haptics", GROUP="feedbackd", MODE="0660", TAG+="uaccess", ENV{FEEDBACKD_TYPE}="vibra"
  '';

  programs = {
    dconf.enable = true;
    kdeconnect.enable = true;

    hyprland = {
      enable = true;
      withUWSM = true;
    };
  };

  services.greetd.settings.initial_session = {
    user = primaryUser;
    command = "${pkgs.uwsm}/bin/uwsm start -e -D Hyprland ${config.programs.hyprland.package}/bin/start-hyprland";
  };

  environment.systemPackages = with pkgs; [
    # foot
    alsa-utils
    ashell
    blueman
    brave
    brightnessctl
    fd
    fuzzel
    iwgtk
    linuxConsoleTools
    lisgd
    maliit-keyboard
    oneplusBrave
    oneplusClipboard
    oneplusKeyboard
    oneplusLauncher
    oneplusOverview
    oneplusRestartSqueekboard
    oneplusScreenRecord
    oneplusSpawn
    oneplusSttDictate
    oneplusTerminalScroll
    oneplusWorkspaceNav
    oneplusHyprctl
    sttDictate
    pavucontrol
    pulseaudio
    squeekboard
    wayland-utils
    wf-recorder
    wl-clipboard
    wtype
    wvkbd
  ];

  hm.primary.services.kdeconnect = {
    enable = true;
    indicator = true;
  };

  hm.primary.dconf.settings."org/gnome/desktop/a11y/applications" = {
    screen-keyboard-enabled = false;
  };

  hm.primary.dconf.settings."org/sigxcpu/feedbackd" = {
    max-haptic-strength = 1.0;
    profile = "quiet";
  };

  hm.primary.dconf.settings."org/sigxcpu/feedbackd/application/sm-puri-squeekboard" = {
    profile = "quiet";
  };

  hm.primary.xdg.desktopEntries = {
    oneplus-brave = {
      name = "Brave Mobile";
      exec = "${oneplusSpawn}/bin/oneplus-spawn ${oneplusBrave}/bin/oneplus-brave %U";
      terminal = false;
      categories = [
        "Network"
        "WebBrowser"
      ];
    };
    oneplus-keyboard = {
      name = "Toggle Keyboard";
      exec = "${oneplusKeyboard}/bin/oneplus-keyboard";
      terminal = false;
      categories = [ "Utility" ];
    };
    oneplus-record-start = {
      name = "Start Screen Recording";
      exec = "${oneplusScreenRecord}/bin/oneplus-screen-record start";
      terminal = false;
      categories = [ "Utility" ];
    };
    oneplus-record-stop = {
      name = "Stop Screen Recording";
      exec = "${oneplusScreenRecord}/bin/oneplus-screen-record stop";
      terminal = false;
      categories = [ "Utility" ];
    };
  };

  systemd.services.oneplus-hyprland-gestures = {
    description = "Touchscreen gestures for the OnePlus Hyprland session";
    wantedBy = [ "graphical.target" ];
    after = [
      "greetd.service"
      "systemd-user-sessions.service"
    ];

    serviceConfig = {
      User = primaryUser;
      SupplementaryGroups = [ "input" ];
      ExecStart = hyprlandGestures;
      Restart = "on-failure";
      RestartSec = "2s";
    };
  };

  hm.primary.xdg.portal = {
    enable = true;
    config = {
      common.default = [ "hyprland" ];
      hyprland.default = [
        "gtk"
        "hyprland"
      ];
    };
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
      pkgs.xdg-desktop-portal-hyprland
    ];
  };

  hm.primary.wayland.windowManager.hyprland = {
    enable = true;
    xwayland.enable = true;
    systemd.enable = false;
    plugins = [ pkgs.hyprlandPlugins.hyprspace ];

    settings = {
      monitor = [ "DSI-1, 1080x2340@60, 0x0, 2" ];

      env = [
        "NIXOS_OZONE_WL,1"
        "MOZ_ENABLE_WAYLAND,1"
        "MOZ_WEBRENDER,1"
        "XDG_SESSION_TYPE,wayland"
        "WLR_NO_HARDWARE_CURSORS,1"
        "WLR_RENDERER_ALLOW_SOFTWARE,1"
      ];

      input = {
        touchdevice.output = "DSI-1";
        follow_mouse = 2;
      };

      general = {
        gaps_in = 0;
        gaps_out = 0;
        border_size = 0;
        layout = "master";
      };

      master = {
        mfact = 0.5;
        orientation = "top";
      };

      binds = {
        allow_workspace_cycles = true;
        workspace_back_and_forth = true;
      };

      decoration = {
        rounding = 0;
        shadow.enabled = false;
      };

      animations = {
        enabled = true;
        bezier = [
          "workspaceSlide,0.22,1,0.36,1"
        ];
        animation = [
          "windows,0,0,default"
          "fade,0,0,default"
          "border,0,0,default"
          "workspaces,1,4,workspaceSlide,slide"
        ];
      };

      misc = {
        disable_hyprland_logo = true;
        disable_splash_rendering = true;
        enable_anr_dialog = false;
        mouse_move_focuses_monitor = false;
      };

      "plugin:overview:panelHeight" = 260;
      "plugin:overview:gapsIn" = 20;
      "plugin:overview:gapsOut" = 200;
      "plugin:overview:onBottom" = true;
      "plugin:overview:affectStrut" = false;
      "plugin:overview:previewMode" = true;
      "plugin:overview:previewModeActiveMargin" = 24;
      "plugin:overview:previewModeActiveGap" = 16;
      "plugin:overview:centerActiveWorkspace" = true;
      "plugin:overview:showEmptyWorkspace" = false;
      "plugin:overview:showNewWorkspace" = false;
      "plugin:overview:previewDragCreateWorkspaceGutters" = true;
      "plugin:overview:previewDragCreateWorkspaceGutterSize" = 72;
      "plugin:overview:previewDragCloseZone" = true;
      "plugin:overview:previewDragCloseZoneHeight" = 160;
      "plugin:overview:disableBlur" = true;
      "plugin:overview:exitOnSwitch" = false;
      "plugin:overview:exitOnClick" = true;

      exec-once = [
        "ashell"
        "${oneplusHyprctl}/bin/oneplus-hyprctl dispatch workspace 10"
        "ghostty --gtk-single-instance=false"
        "squeekboard"
      ];
    };
  };

  hm.primary.home.file.".local/share/squeekboard/keyboards/terminal/us.yaml".source =
    ./squeekboard-keyboards/terminal/us.yaml;

  hm.primary.systemd.user.services.oneplus-restart-squeekboard = {
    Unit.Description = "Restart Squeekboard after OnePlus keyboard layout changes";
    Service = {
      Type = "oneshot";
      ExecStart = "${oneplusRestartSqueekboard}/bin/oneplus-restart-squeekboard";
    };
  };

  hm.primary.systemd.user.paths.oneplus-restart-squeekboard = {
    Unit.Description = "Watch OnePlus Squeekboard keyboard layout for changes";
    Path.PathChanged = "%h/.local/share/squeekboard/keyboards/terminal/us.yaml";
    Install.WantedBy = [ "default.target" ];
  };

  hm.primary.home.file.".config/fuzzel/fuzzel.ini".text = ''
    [main]
    font=monospace:size=18
    dpi-aware=no
    layer=top
    width=32
    lines=10
    tabs=4
    horizontal-pad=24
    vertical-pad=18
    inner-pad=10
    prompt=›
    terminal=ghostty

    [colors]
    background=1f1f28f2
    text=dcd7baff
    match=ffa066ff
    selection=2d4f67ff
    selection-text=dcd7baff
    border=7e9cd8ff

    [border]
    width=2
    radius=12
  '';

  hm.primary.home.file.".config/ashell/config.toml".text = ''
    log_level = "warn"
    position = "Top"
    layer = "Top"

    [modules]
    left = [ [ "LeftPad", "Tempo" ] ]
    center = []
    right = [ [ "Settings", "RightPad" ] ]

    [tempo]
    clock_format = "%H:%M"
    weather_indicator = "None"

    [settings]
    enable_tooltips = false
    battery_format = "IconAndPercentage"
    network_indicator_format = "Icon"
    bluetooth_indicator_format = "Icon"
    brightness_indicator_format = "Icon"
    audio_indicator_format = "Icon"
    microphone_indicator_format = "Icon"
    indicators = [ "Network", "Bluetooth", "Audio", "Microphone", "Battery", "Brightness" ]
    wifi_more_cmd = "iwgtk"
    bluetooth_more_cmd = "blueman-manager"
    audio_sinks_more_cmd = "pavucontrol -t 3"
    audio_sources_more_cmd = "pavucontrol -t 4"
    shutdown_cmd = "systemctl poweroff"
    reboot_cmd = "systemctl reboot"
    logout_cmd = "loginctl kill-user ${primaryUser}"

    [[CustomModule]]
    name = "LeftPad"
    type = "Text"
    listen_cmd = "printf '{\"text\": \" \", \"alt\": \"\"}\\n'"

    [[CustomModule]]
    name = "RightPad"
    type = "Text"
    listen_cmd = "printf '{\"text\": \" \", \"alt\": \"\"}\\n'"

    [appearance]
    style = "Solid"
    scale_factor = 1.6
    opacity = 0.92
  '';
}
