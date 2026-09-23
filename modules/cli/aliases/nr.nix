{
  pkgs,
  config,
}:
let
  generateHostImports = pkgs.callPackage ../../../scripts/generate-host-imports.nix { };
  activate = import ./activate.nix { inherit pkgs; };
in
pkgs.writeShellApplication {
  name = "nr";
  text = ''
    ${generateHostImports}/bin/generate-host-imports "${config.hostSpec.hostName}" --repo "${config.hostSpec.dotfiles}"
    candidate="''${XDG_STATE_HOME:-$HOME/.local/state}/nixos-deploy/candidate"
    mkdir -p "$(dirname "$candidate")"
    ${pkgs.nix}/bin/nix build --accept-flake-config --out-link "$candidate" \
      '${config.hostSpec.dotfiles}#nixosConfigurations.${config.hostSpec.hostName}.config.system.build.toplevel'
    ${activate}/bin/nixos-activate-detached "$(readlink -f "$candidate")"
  '';
}
