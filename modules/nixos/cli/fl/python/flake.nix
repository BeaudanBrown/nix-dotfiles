{
  inputs = {
    nixpkgs.url = "github:cachix/devenv-nixpkgs/rolling";
    systems.url = "github:nix-systems/default";
    devenv.url = "github:cachix/devenv";
    devenv.inputs.nixpkgs.follows = "nixpkgs";
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

            # gitPkg = pkgs.python3Packages.buildPythonPackage {
            #   pname = "";
            #   version = "";
            #   src = pkgs.fetchFromGitHub {
            #     owner = "";
            #     repo = "";
            #     rev = "";
            #     sha256 = "";
            #   };
            # };

            # pyPiPkg = with pkgs.python3Packages; buildPythonPackage rec {
            #   pname = "";
            #   version = "";
            #   src = fetchPypi {
            #     inherit pname version;
            #     sha256 = "";
            #   };
            #   doCheck = false;
            #   checkInputs = [];
            #   propagatedBuildInputs = [];
            #   dependencies = [];
            # };

          in
          {
            default = devenv.lib.mkShell {
              inherit inputs pkgs;
              modules = [
                {
                  packages = with pkgs; [
                    (python3.withPackages (python-pkgs: with python-pkgs; [
                    ]))
                  ];
                }
              ];
            };
          });
    };
}
