{ config, pkgs, ... }:
let
  oneplusVncView = pkgs.writeShellApplication {
    name = "oneplus-vnc-view";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.netcat-openbsd
      pkgs.openssh
      pkgs.remmina
      pkgs.tigervnc
    ];
    text = ''
      set -euo pipefail

      remote="''${ONEPLUS_VNC_HOST:-oneplus}"
      local_port="''${ONEPLUS_VNC_LOCAL_PORT:-5901}"
      remote_port="''${ONEPLUS_VNC_REMOTE_PORT:-5900}"
      viewer="''${ONEPLUS_VNC_VIEWER:-remmina}"

      tunnel_pid=""
      cleanup() {
        if [ -n "$tunnel_pid" ] && kill -0 "$tunnel_pid" 2>/dev/null; then
          kill "$tunnel_pid" 2>/dev/null || true
        fi
        ssh "$remote" oneplus-vnc stop >/dev/null 2>&1 || true
      }
      trap cleanup EXIT INT TERM

      ssh "$remote" oneplus-vnc start

      for _ in $(seq 1 50); do
        if ssh "$remote" nc -z 127.0.0.1 "$remote_port" >/dev/null 2>&1; then
          break
        fi
        sleep 0.1
      done

      ssh \
        -o ExitOnForwardFailure=yes \
        -o ServerAliveInterval=15 \
        -o ServerAliveCountMax=3 \
        -N \
        -L "127.0.0.1:$local_port:127.0.0.1:$remote_port" \
        "$remote" &
      tunnel_pid="$!"

      for _ in $(seq 1 50); do
        if nc -z 127.0.0.1 "$local_port" >/dev/null 2>&1; then
          break
        fi
        sleep 0.1
      done

      case "$viewer" in
        remmina)
          remmina -c "vnc://127.0.0.1:$local_port"
          ;;
        tigervnc)
          vncviewer "127.0.0.1::$local_port"
          ;;
        *)
          echo "Unknown ONEPLUS_VNC_VIEWER: $viewer" >&2
          echo "Use 'remmina' or 'tigervnc'." >&2
          exit 64
          ;;
      esac
    '';
  };
in
{
  environment.systemPackages = [
    oneplusVncView
    pkgs.remmina
    pkgs.tigervnc
  ];

  hm.primary.xdg.desktopEntries.oneplus-vnc-view = {
    name = "View OnePlus Screen";
    exec = "${oneplusVncView}/bin/oneplus-vnc-view";
    terminal = false;
    categories = [
      "Network"
      "RemoteAccess"
    ];
  };

  hm.primary.programs.ssh.settings.oneplus = {
    HostName = "oneplus.lan";
    User = config.hostSpec.username;
  };
}
