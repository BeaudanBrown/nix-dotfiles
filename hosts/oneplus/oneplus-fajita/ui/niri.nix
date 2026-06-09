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
    socket="$(${pkgs.findutils}/bin/find "$runtime_dir" -maxdepth 1 -type s -name 'niri.*.sock' | ${pkgs.coreutils}/bin/head -n1)"
    if [ -z "$socket" ]; then
      echo "No niri socket found" >&2
      exit 1
    fi

    exec ${pkgs.util-linux}/bin/runuser -u ${primaryUser} -- env \
      XDG_RUNTIME_DIR="$runtime_dir" \
      NIRI_SOCKET="$socket" \
      ${config.programs.niri.package}/bin/niri msg "$@"
  '';
  niriGestures = pkgs.writeShellScript "oneplus-niri-gestures" ''
    exec ${pkgs.lisgd}/bin/lisgd \
      -d /dev/input/by-path/platform-a90000.i2c-event \
      -w 1080 \
      -h 2340 \
      -s 2 \
      -g '1,DU,B,*,R,${niriMsg}/bin/oneplus-niri-msg action toggle-overview' \
      -g '1,LR,L,*,R,${niriMsg}/bin/oneplus-niri-msg action focus-column-left' \
      -g '1,RL,R,*,R,${niriMsg}/bin/oneplus-niri-msg action focus-column-right'
  '';
in
{
  hardware.graphics.enable = true;

  programs.niri = {
    enable = true;
    useNautilus = false;
  };

  services.greetd.settings.initial_session = {
    user = primaryUser;
    command = "${config.programs.niri.package}/bin/niri-session";
  };

  environment.systemPackages = with pkgs; [
    # foot
    ashell
    blueman
    brightnessctl
    iwgtk
    lisgd
    pavucontrol
    squeekboard
    wayland-utils
    wl-clipboard
    wtype
    wvkbd
  ];

  systemd.services.oneplus-niri-gestures = {
    description = "Touchscreen gestures for the OnePlus Niri session";
    wantedBy = [ "graphical.target" ];
    after = [
      "greetd.service"
      "systemd-user-sessions.service"
    ];

    serviceConfig = {
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
    scale_factor = 1.0
    opacity = 0.92
  '';
}
