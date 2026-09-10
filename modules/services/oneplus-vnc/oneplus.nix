{ config, pkgs, ... }:
let
  primaryUser = config.hostSpec.username;
  oneplusVnc = pkgs.writeShellScriptBin "oneplus-vnc" ''
    set -eu

    uid="$(${pkgs.coreutils}/bin/id -u ${primaryUser})"
    if [ "$(${pkgs.coreutils}/bin/id -u)" != "$uid" ]; then
      exec ${pkgs.util-linux}/bin/runuser -u ${primaryUser} -- "$0" "$@"
    fi

    runtime_dir="/run/user/$uid"
    wayland_socket="$(${pkgs.findutils}/bin/find "$runtime_dir" -maxdepth 1 -type s -name 'wayland-*' -print -quit 2>/dev/null)"
    if [ -z "$wayland_socket" ]; then
      echo "No Wayland socket found under $runtime_dir" >&2
      exit 1
    fi

    export XDG_RUNTIME_DIR="$runtime_dir"
    export WAYLAND_DISPLAY="$(${pkgs.coreutils}/bin/basename "$wayland_socket")"
    export DBUS_SESSION_BUS_ADDRESS="unix:path=$runtime_dir/bus"

    state_dir="$runtime_dir/oneplus-vnc"
    pidfile="$state_dir/pid"
    logfile="$state_dir/log"
    mkdir -p "$state_dir"

    cmd="''${1:-status}"
    shift || true

    case "$cmd" in
      start)
        if [ -s "$pidfile" ] && ${pkgs.procps}/bin/kill -0 "$(${pkgs.coreutils}/bin/cat "$pidfile")" 2>/dev/null; then
          echo "OnePlus VNC already running on 127.0.0.1:5900"
          exit 0
        fi

        : >"$logfile"
        ${pkgs.util-linux}/bin/setsid ${pkgs.wayvnc}/bin/wayvnc \
          --output DSI-1 \
          --max-fps 30 \
          --render-cursor \
          127.0.0.1 \
          5900 \
          >>"$logfile" 2>&1 < /dev/null &
        pid="$!"
        printf '%s\n' "$pid" >"$pidfile"
        echo "OnePlus VNC started on 127.0.0.1:5900"
        ;;
      stop)
        if [ ! -s "$pidfile" ]; then
          echo "OnePlus VNC is not running"
          exit 0
        fi

        pid="$(${pkgs.coreutils}/bin/cat "$pidfile")"
        if ${pkgs.procps}/bin/kill -0 "$pid" 2>/dev/null; then
          ${pkgs.procps}/bin/kill "$pid"
          for _ in $(${pkgs.coreutils}/bin/seq 1 50); do
            ${pkgs.procps}/bin/kill -0 "$pid" 2>/dev/null || break
            ${pkgs.coreutils}/bin/sleep 0.1
          done
        fi
        ${pkgs.coreutils}/bin/rm -f "$pidfile"
        echo "OnePlus VNC stopped"
        ;;
      status)
        if [ -s "$pidfile" ] && ${pkgs.procps}/bin/kill -0 "$(${pkgs.coreutils}/bin/cat "$pidfile")" 2>/dev/null; then
          echo "OnePlus VNC running on 127.0.0.1:5900"
        else
          echo "OnePlus VNC not running"
        fi
        ;;
      log)
        exec ${pkgs.coreutils}/bin/tail -n 80 "$logfile"
        ;;
      *)
        echo "Usage: oneplus-vnc start|stop|status|log" >&2
        exit 64
        ;;
    esac
  '';
in
{
  environment.systemPackages = [
    oneplusVnc
    pkgs.netcat-openbsd
    pkgs.wayvnc
  ];

  hm.primary.xdg.desktopEntries = {
    oneplus-vnc-start = {
      name = "Start VNC Sharing";
      exec = "${oneplusVnc}/bin/oneplus-vnc start";
      terminal = false;
      categories = [ "Utility" ];
    };
    oneplus-vnc-stop = {
      name = "Stop VNC Sharing";
      exec = "${oneplusVnc}/bin/oneplus-vnc stop";
      terminal = false;
      categories = [ "Utility" ];
    };
  };
}
