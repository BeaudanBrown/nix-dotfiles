{
  inputs = {
    nixpkgs.url = "github:cachix/devenv-nixpkgs/rolling";
    systems.url = "github:nix-systems/default";
    devenv.url = "github:cachix/devenv";
  };

  nixConfig = {
    extra-trusted-public-keys = "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=";
    extra-substituters = "https://devenv.cachix.org";
  };

  outputs = { self, nixpkgs, devenv, systems, ... } @ inputs:
    let
      forEachSystem = nixpkgs.lib.genAttrs (import systems);
    in
    {
      packages = forEachSystem (system: {
        devenv-up = self.devShells.${system}.default.config.procfileScript;
      });

      devShells = forEachSystem
        (system:
          let
            pkgs = nixpkgs.legacyPackages.${system};
            rPkgs = (with pkgs.rPackages; [
              languageserver
              dotenv
              quarto
            ]);
            my-r = pkgs.rWrapper.override {
              packages = rPkgs;
            };
            my-quarto = pkgs.quarto.override {
              extraRPackages = rPkgs;
            };
          in
          {
            default = devenv.lib.mkShell {
              inherit inputs pkgs;
              modules = [
                {
                  packages = with pkgs; [
                    my-r
                    my-quarto
                    icu.dev
                    glibcLocales
                  ];

                  env.R_LIBS_USER="./.Rlib";
                }
              ];
            };
          });
    };
}
