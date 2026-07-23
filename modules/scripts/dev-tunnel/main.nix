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

        port="''${1:-8000}"
        if [[ ! "$port" =~ ^[0-9]+$ ]] || (( 10#$port < 1 || 10#$port > 65535 )); then
          echo "local-port must be an integer from 1 to 65535" >&2
          exit 64
        fi

        echo "WARNING: https://dev.bepis.lol will publicly expose 127.0.0.1:$port until this command stops." >&2
        echo "Press Ctrl-C to close the tunnel and remove public access." >&2

        exec ssh -N -T \
          -o ExitOnForwardFailure=yes \
          -o ServerAliveInterval=30 \
          -o ServerAliveCountMax=3 \
          -R "127.0.0.1:18000:127.0.0.1:$port" \
          nas
      '';
    })
  ];
}
