{
  outputs = { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
        {
        devShells.default = pkgs.mkShell {
          env.R_LIBS_USER="./.Rlib";
          packages = with pkgs;
            [
              R
              quarto
            ] ++ (with rPackages;
              [
                languageserver
                dotenv
              ]);
        };
      }
    );

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    systems.url = "github:nix-systems/default";
    flake-utils = {
      url = "github:numtide/flake-utils";
      inputs.systems.follows = "systems";
    };
  };
}
