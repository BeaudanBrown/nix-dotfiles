{ config, pkgs, ... }:
let
  kindleSend = pkgs.writeShellApplication {
    name = "kindle-send";
    runtimeInputs = [
      pkgs.nix
      pkgs.openssh
    ];
    text = ''
      set -euo pipefail

      usage() {
        echo "Usage: kindle-send <nixpkgs-package-attribute>" >&2
        echo "Example: kindle-send htop" >&2
      }

      if [ "$#" -ne 1 ]; then
        usage
        exit 2
      fi

      package="$1"
      if [[ ! "$package" =~ ^[[:alnum:]_+-]+(\.[[:alnum:]_+-]+)*$ ]]; then
        echo "Invalid package attribute: $package" >&2
        exit 2
      fi

      host="''${KINDLE_HOST:-kindle}"
      flake="${config.hostSpec.dotfiles}"
      installable="$flake#legacyPackages.${pkgs.stdenv.hostPlatform.system}.kindle.$package^out"

      # Fail before spending time cross-building when the Kindle has not been
      # initialized with kindle-nix's ext4-backed closure receiver.
      ssh "$host" test -x /nix/bin/kindle-nix-install

      mapfile -t outputs < <(
        nix build "$installable" --no-link --print-out-paths
      )

      if [ "''${#outputs[@]}" -ne 1 ]; then
        echo "Expected exactly one out path, got ''${#outputs[@]}" >&2
        exit 1
      fi

      output="''${outputs[0]}"
      nix copy --to "ssh://$host" "$output"
      # shellcheck disable=SC2029 # Pass the local store path to the remote helper.
      ssh "$host" /nix/bin/kindle-nix-install "$output"

      echo "Installed $package on $host"
    '';
  };
in
{
  environment.systemPackages = [ kindleSend ];
}
