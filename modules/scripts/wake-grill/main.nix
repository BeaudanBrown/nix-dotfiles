{ pkgs, ... }:
{
  environment.systemPackages = [
    (pkgs.writeShellApplication {
      name = "wake-grill";
      runtimeInputs = [ pkgs.curl ];
      text = ''
        status=$(curl --disable --silent --show-error --output /dev/null \
          --write-out '%{http_code}' --max-time 10 \
          --request POST --header 'X-Wake-Grill: 1' \
          'https://wake.bepis.lol/grill')
        if [[ "$status" != 204 ]]; then
          printf 'Wake request failed (HTTP %s).\n' "$status" >&2
          exit 1
        fi
        echo 'Wake packet sent.'
      '';
    })
  ];
}
