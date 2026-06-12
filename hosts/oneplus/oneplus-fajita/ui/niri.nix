{
  config,
  pkgs,
  ...
}:
let
  primaryUser = config.hostSpec.username;
  niriMsg = pkgs.writeShellScriptBin "oneplus-niri-msg" ''
    set -eu

    uid="$(${pkgs.coreutils}/bin/id -u ${primaryUser})"
    runtime_dir="/run/user/$uid"
    socket="$(${pkgs.findutils}/bin/find "$runtime_dir" -maxdepth 1 -type s -name 'niri.*.sock' -print -quit 2>/dev/null)"
    if [ -z "$socket" ]; then
      echo "No niri socket found" >&2
      exit 1
    fi

    if [ "$(${pkgs.coreutils}/bin/id -u)" = "$uid" ]; then
      exec env \
        XDG_RUNTIME_DIR="$runtime_dir" \
        NIRI_SOCKET="$socket" \
        ${config.programs.niri.package}/bin/niri msg "$@"
    fi

    exec ${pkgs.util-linux}/bin/runuser -u ${primaryUser} -- env \
      XDG_RUNTIME_DIR="$runtime_dir" \
      NIRI_SOCKET="$socket" \
      ${config.programs.niri.package}/bin/niri msg "$@"
  '';
  oneplusSpawn = pkgs.writeShellScriptBin "oneplus-spawn" ''
    set -eu

    if [ "$#" -eq 0 ]; then
      echo "Usage: oneplus-spawn COMMAND [ARGS...]" >&2
      exit 64
    fi

    exec ${niriMsg}/bin/oneplus-niri-msg action spawn -- "$@"
  '';
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

    if ${pkgs.procps}/bin/pgrep -u ${primaryUser} -x wvkbd-mobintl >/dev/null; then
      exec ${pkgs.procps}/bin/pkill -u ${primaryUser} -x wvkbd-mobintl
    fi

    exec ${oneplusSpawn}/bin/oneplus-spawn ${pkgs.wvkbd}/bin/wvkbd-mobintl
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
  niriGestures = pkgs.writeShellScript "oneplus-niri-gestures" ''
    exec ${pkgs.lisgd}/bin/lisgd \
      -v \
      -d /dev/input/by-path/platform-a90000.i2c-event \
      -w 1080 \
      -h 2340 \
      -m 1200 \
      -t 60 \
      -r 35 \
      -s 2 \
      -g '1,DU,B,*,R,${niriMsg}/bin/oneplus-niri-msg action toggle-overview' \
      -g '1,LR,L,*,R,${niriMsg}/bin/oneplus-niri-msg action focus-column-left' \
      -g '1,RL,R,*,R,${niriMsg}/bin/oneplus-niri-msg action focus-column-right' \
      -g '2,DU,*,*,R,${oneplusSpawn}/bin/oneplus-spawn ${pkgs.nwg-drawer}/bin/nwg-drawer'
  '';
in
{
  hardware.graphics.enable = true;

  programs = {
    kdeconnect.enable = true;

    niri = {
      enable = true;
      useNautilus = false;
    };
  };

  services.greetd.settings.initial_session = {
    user = primaryUser;
    command = "${config.programs.niri.package}/bin/niri-session";
  };

  environment.systemPackages = with pkgs; [
    # foot
    ashell
    blueman
    brave
    brightnessctl
    iwgtk
    linuxConsoleTools
    lisgd
    maliit-keyboard
    nwg-drawer
    oneplusBrave
    oneplusClipboard
    oneplusKeyboard
    oneplusScreenRecord
    oneplusSpawn
    niriMsg
    pavucontrol
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

  systemd.services.oneplus-niri-gestures = {
    description = "Touchscreen gestures for the OnePlus Niri session";
    wantedBy = [ "graphical.target" ];
    after = [
      "greetd.service"
      "systemd-user-sessions.service"
    ];

    serviceConfig = {
      User = primaryUser;
      SupplementaryGroups = [ "input" ];
      ExecStart = niriGestures;
      Restart = "on-failure";
      RestartSec = "2s";
    };
  };

  hm.primary.home.file.".config/niri/config.kdl".text = ''
    input {
        touch {
            map-to-output "DSI-1"
        }
    }
    layout {
        gaps 0
        default-column-width { proportion 1.0; }
        focus-ring {
            off
        }

        border {
            off
        }
    }


    output "DSI-1" {
        scale 2
    }

    prefer-no-csd
    spawn-at-startup "ashell"
    spawn-at-startup "ghostty"
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
    indicators = [ "Network", "Bluetooth", "Audio", "Battery", "Brightness" ]
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
    listen_cmd = "printf '{\"text\": \"   \", \"alt\": \"\"}\\n'"

    [[CustomModule]]
    name = "RightPad"
    type = "Text"
    listen_cmd = "printf '{\"text\": \"   \", \"alt\": \"\"}\\n'"

    [appearance]
    style = "Solid"
    scale_factor = 1.6
    opacity = 0.92
  '';
}
