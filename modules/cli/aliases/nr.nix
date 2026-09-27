{
  pkgs,
  config,
}:
let
  generateHostImports = pkgs.callPackage ../../../scripts/generate-host-imports.nix { };
in
pkgs.writeShellApplication {
  name = "nr";
  text = ''
    ${generateHostImports}/bin/generate-host-imports "${config.hostSpec.hostName}" --repo "${config.hostSpec.dotfiles}"
    ${pkgs.nh}/bin/nh os switch "${config.hostSpec.dotfiles}" --accept-flake-config
  '';
}
