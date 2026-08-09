{ pkgs, ... }:
{
  environment.systemPackages = [
    (pkgs.writeShellApplication {
      name = "dev-tunnel";
      runtimeInputs = [ pkgs.openssh ];
      text = ''
        set -euo pipefail

        if [ "$#" -gt 1 ]; then
          echo "Usage: dev-tunnel [local-port]" >&2
          exit 64
        fi

        app_port="''${1:-8000}"
        if [[ ! "$app_port" =~ ^[0-9]+$ ]] || (( 10#$app_port < 1 || 10#$app_port > 65534 )); then
          echo "local-port must be an integer from 1 to 65534" >&2
          exit 64
        fi
        tool_port=$((10#$app_port + 1))

        echo "WARNING: https://dev.bepis.lol will publicly expose the app on 127.0.0.1:$app_port and IHP livereload on 127.0.0.1:$tool_port until this command stops." >&2
        echo "Press Ctrl-C to close the tunnel and remove public access." >&2

        exec ssh -N -T \
          -o ExitOnForwardFailure=yes \
          -o ServerAliveInterval=30 \
          -o ServerAliveCountMax=3 \
          -R "127.0.0.1:20080:127.0.0.1:$app_port" \
          -R "127.0.0.1:20081:127.0.0.1:$tool_port" \
          nas
      '';
    })
  ];
}
